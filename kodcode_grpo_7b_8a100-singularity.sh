#!/bin/bash
# The config is optimized for 8xA100 (Singularity)
set -x

# Get the base model from the command line
BASE_MODEL=${1:-"Qwen/Qwen2.5-7B-Instruct-1M"}
MAX_EPOCHS=${2:-"8"}
DATASET=${3:-"kodcode_hard-9k-sing"}

if [ -z "$CUDA_VISIBLE_DEVICES" ]; then
    GPUS_PER_NODE=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
else
    GPUS_PER_NODE=$(echo "$CUDA_VISIBLE_DEVICES" | awk -F',' '{print NF}')
fi

# MAIN CONFIG
MODEL_PATH=$BASE_MODEL
ROLLOUT_N_SAMPLE=16
ROLLOUT_N_QUERY=16
MICRO_BATCH_PER_GPU=2 # * GPUS_PER_NODE -> GLOBAL_BATCH_SIZE
GRAD_ACC_STEPS=16
GLOBAL_BATCH_SIZE=$(($(($GPUS_PER_NODE * $MICRO_BATCH_PER_GPU)) * $GRAD_ACC_STEPS))

MODEL_NICKNAME=$(echo $MODEL_PATH | cut -d'/' -f2)
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RUN_NAME=${MODEL_NICKNAME}-${DATASET}

# assert ROLLOUT_N_QUERY * ROLLOUT_N_SAMPLE % GLOBAL_BATCH_SIZE == 0
TOTAL_SAMPLES=$(( ROLLOUT_N_QUERY * ROLLOUT_N_SAMPLE ))
if (( TOTAL_SAMPLES % GLOBAL_BATCH_SIZE != 0 )); then
    echo "Error: (ROLLOUT_N_QUERY * ROLLOUT_N_SAMPLE) must be divisible by GLOBAL_BATCH_SIZE."
    echo "Currently, ${TOTAL_SAMPLES} is not divisible by ${GLOBAL_BATCH_SIZE}."
    exit 1
else
    echo "Assertion passed: ${TOTAL_SAMPLES} is divisible by ${GLOBAL_BATCH_SIZE}."
fi

SAVED_DIR="/v-zhangcxu/models_rl/${RUN_NAME}"
MAX_PROMPT_LEN=1536
MAX_RESPONSE_LEN=4096
PPO_MAX_TOKEN_LEN_PER_GPU=$(( 3 * $(( $MAX_PROMPT_LEN + $MAX_RESPONSE_LEN )) ))

python3 -m verl.trainer.main_ppo \
    algorithm.adv_estimator=grpo \
    data.train_files=/v-zhangcxu/data_rl/$DATASET/train.parquet \
    data.val_files=/v-zhangcxu/data_rl/$DATASET/test.parquet \
    data.train_batch_size=$GLOBAL_BATCH_SIZE \
    data.max_prompt_length=$MAX_PROMPT_LEN \
    data.max_response_length=$MAX_RESPONSE_LEN \
    data.filter_overlong_prompts=True \
    data.truncation='error' \
    actor_rollout_ref.model.path=$MODEL_PATH \
    actor_rollout_ref.actor.optim.lr=5e-7 \
    actor_rollout_ref.model.use_remove_padding=True \
    actor_rollout_ref.actor.ppo_mini_batch_size=$GLOBAL_BATCH_SIZE \
    actor_rollout_ref.actor.ppo_max_token_len_per_gpu=$PPO_MAX_TOKEN_LEN_PER_GPU \
    actor_rollout_ref.actor.use_dynamic_bsz=True \
    actor_rollout_ref.actor.use_kl_loss=True \
    actor_rollout_ref.actor.kl_loss_coef=0.001 \
    actor_rollout_ref.actor.kl_loss_type=low_var_kl \
    actor_rollout_ref.model.enable_gradient_checkpointing=True \
    actor_rollout_ref.actor.fsdp_config.param_offload=False \
    actor_rollout_ref.actor.fsdp_config.optimizer_offload=True \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.4 \
    actor_rollout_ref.rollout.n=$ROLLOUT_N_SAMPLE \
    actor_rollout_ref.ref.fsdp_config.param_offload=False \
    algorithm.kl_ctrl.kl_coef=0.001 \
    trainer.critic_warmup=0 \
    trainer.logger=['console','wandb'] \
    trainer.project_name='code-r1' \
    trainer.experiment_name=${RUN_NAME} \
    trainer.nnodes=1 \
    trainer.default_local_dir=$SAVED_DIR \
    trainer.n_gpus_per_node=$GPUS_PER_NODE \
    trainer.save_freq=32 \
    trainer.test_freq=16 \
    trainer.resume_mode=auto \
    trainer.remove_previous_ckpt_in_save=False \
    trainer.total_epochs=$MAX_EPOCHS \
    reward_model.reward_manager=prime 2>&1 | tee ${RUN_NAME}.log