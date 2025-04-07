#!/bin/bash
# The config is optimized for 8xA100 (Singularity)
set -x

# Get the base model from the command line
BASE_MODEL=${1:-"Qwen/Qwen2.5-7B-Instruct-1M"}
MAX_EPOCHS=${2:-"8"}
DATASET=${3:-"kodcode-9k-sing"}

if [ -z "$CUDA_VISIBLE_DEVICES" ]; then
    GPUS_PER_NODE=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
else
    GPUS_PER_NODE=$(echo "$CUDA_VISIBLE_DEVICES" | awk -F',' '{print NF}')
fi

# MAIN CONFIG
MODEL_PATH=$BASE_MODEL
ROLLOUT_BATCH_SIZE=256
ROLLOUT_N_SAMPLE=16
PPO_MINI_BATCH_SIZE=256

MODEL_NICKNAME=$(echo $MODEL_PATH | cut -d'/' -f2)
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RUN_NAME=${MODEL_NICKNAME}-${DATASET}

TOTAL_SAMPLES=$(( PPO_MINI_BATCH_SIZE * ROLLOUT_N_SAMPLE )) # Number of experiences per step
echo "Number of experiences: $TOTAL_SAMPLES"

SAVED_DIR="/v-zhangcxu/models_rl/${RUN_NAME}"
MAX_PROMPT_LEN=1536
MAX_RESPONSE_LEN=4096
PPO_MAX_TOKEN_LEN_PER_GPU=$(( 3 * $(( $MAX_PROMPT_LEN + $MAX_RESPONSE_LEN )) ))

# Since we updated vllm to 0.8.2, we don't need to set the attention backend
# export VLLM_ATTENTION_BACKEND=XFORMERS

python3 -m verl.trainer.main_ppo \
    algorithm.adv_estimator=grpo \
    data.train_files=/v-zhangcxu/data_rl/$DATASET/train.parquet \
    data.val_files=/v-zhangcxu/data_rl/$DATASET/test.parquet \
    data.train_batch_size=$ROLLOUT_BATCH_SIZE \
    data.max_prompt_length=$MAX_PROMPT_LEN \
    data.max_response_length=$MAX_RESPONSE_LEN \
    data.filter_overlong_prompts=True \
    data.truncation='error' \
    actor_rollout_ref.model.path=$MODEL_PATH \
    actor_rollout_ref.actor.optim.lr=5e-7 \
    actor_rollout_ref.model.use_remove_padding=True \
    actor_rollout_ref.actor.ppo_mini_batch_size=$PPO_MINI_BATCH_SIZE \
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
    actor_rollout_ref.rollout.enforce_eager=False \
    actor_rollout_ref.rollout.free_cache_engine=False \
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