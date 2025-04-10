"""
Preprocess LeetCode problems (newfacade/LeetCodeDataset) to parquet format.
"""

import os
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from datasets import load_dataset, concatenate_datasets
from rich.rule import Rule
import rich

import datasets
# Override datasets disk space check for singularity
datasets.builder.has_sufficient_disk_space = lambda needed_bytes, directory='.': True

N_TESTSET_PER_DATASET = 512  # per dataset
_EMPTY_RETURN_ = {
    "data_source": None,
    "prompt": None,
    "ability": None,
    "reward_model": None,
    "extra_info": None,
}

from verl.utils.reward_score.coder1 import code_exec, remote_check_stdio, _ERROR_MSG_PREFIX

SYSTEM_PROMPT = """As a programming assistant, your task is to thoroughly analyze coding questions through a systematic thinking process before delivering precise, accurate solutions. This involves a comprehensive approach that includes:

1. Understanding the problem requirements and expected behavior
2. Breaking down complex problems into manageable components
3. Exploring potential approaches and their tradeoffs
4. Implementing a solution with clear, well-documented code

Follow test-driven development principles by:
1. First understanding the requirements and expected behavior
2. Brainstorming test cases covering normal scenarios, edge cases, and corner cases
3. Implementing code that addresses these test cases. You do not have interpreter, so you need to carefully check your code to make sure it can pass the test cases
4. Refining the solution through iteration when necessary

If test examples are provided in the question, analyze them carefully to understand the expected behavior. If no tests are provided, create appropriate test cases before implementing the solution. Pay special attention to edge cases such as empty inputs, boundary values, and special character handling.

Structure your response into two clearly defined sections:
1. <think>...</think> - Include detailed analysis, problem breakdown, verification steps, and iterative refinement.
2. <answer>...</answer> - Provide a self-contained, complete solution with all necessary imports, well-structured code, and clear explanations."""

def kodcode():  # Thanks!!! to Zhangchen and Yueqin
    # library requirements?
    rich.print(Rule("Loading KodCode..."))
    dataset = load_dataset("KodCode/KodCode-Light-RL-10K")

    # Filter the dataset based on the specified criteria
    rich.print(Rule("Filtering KodCode dataset..."))
    def filter_criteria(example):
        # Check if 'example' (case-insensitive) is NOT in the question
        question_ok = 'example' not in example['question'].lower()
        # Check if 'def' appears >= 4 times in the test code
        test_ok = example['test'].count('def') >= 4
        # Check if the subset is 'Filter' or 'Prefill'
        # NOTE: This assumes a 'subset' column exists in the dataset.
        subset_ok = example.get('subset') in ['Filter', 'Prefill'] # Use .get() for safety
        return question_ok and test_ok and subset_ok

    filtered_dataset = dataset.filter(
        filter_criteria,
        num_proc=48, # Use multiple processes for filtering if desired
    )
    rich.print(f"Dataset size after filtering: {len(filtered_dataset['train'])}")

    packages = [
        "beautifulsoup4", "fake-useragent", "imageio", "keras", "lxml", "matplotlib", "numpy", "opencv-python",
        "pillow", "requests", "rich", "scikit-learn", "sphinx-pyproject", "statsmodels", "sympy", "tweepy",
        "typing_extensions", "xgboost", "flask", "seaborn"
    ]
    block_libs = [
        "fake-useragent", "keras", "socket", "torch", "scipy", "sklearn", "cv2", "scipy", "imageio", "sphinx-pyproject",
        "xgboost", "tweepy", "flask", "matplotlib", "pillow", "seaborn", "smtpd", "pandas"
    ]

    def make_map_fn(split):

        def process_fn(example, idx):
            reference_solution = example["solution"]
            test_code = "from solution import *\n" + example["test"].strip()
            # skip it if reference solution requires libs from block_libs
            if any(lib in reference_solution for lib in block_libs):
                return _EMPTY_RETURN_
            if any(lib in test_code for lib in block_libs):
                return _EMPTY_RETURN_
            prompt = f"Please solve the programming task below in Python. \n\n{example['question'].strip()}"
            test_declaration = example["test_info"][0]["function_declaration"].strip()
            if test_declaration and test_declaration.strip():
                prompt += f"\n\nNote that the function declaration is {test_declaration}. Your code should be wrapped in a markdown code block."

            try:
                succ, err = code_exec(code=reference_solution, pytest=test_code)
                if not succ:
                    rich.print(f"[bold red]Test code failed for {example['question_id']}")
                    print(reference_solution)
                    print(err)
                    return _EMPTY_RETURN_
            except Exception as e:
                rich.print(f"[bold red]Exception during code execution for {example['question_id']}: {str(e)}")
                return _EMPTY_RETURN_

            return {
                "data_source": "code_simple",
                "prompt": [
                    {
                        "role": "system",
                        "content": SYSTEM_PROMPT
                    },
                    {
                        "role": "user",
                        "content": prompt
                    },
                ],
                "ability": "coding",
                "reward_model": {
                    "style": "rule",
                    "ground_truth": json.dumps({"pytest": test_code}),
                },
                "extra_info": {
                    "split": split,
                    "index": idx,
                    "reference": reference_solution,
                    "prompt": prompt,
                    "dataset": "KodCode/KodCode-Light-RL-10K",
                },
            }

        return process_fn

    # Apply the mapping function to the *filtered* dataset
    mapped_dataset = filtered_dataset.map(
        function=make_map_fn("train"),
        with_indices=True,
        num_proc=48,
    ).filter(lambda x: x != _EMPTY_RETURN_)
    # Perform train/test split on the mapped and non-empty dataset
    splits = mapped_dataset['train'].shuffle(seed=666).filter(lambda x: x['prompt'] is not None).train_test_split(test_size=N_TESTSET_PER_DATASET, seed=666)
    train_dataset = splits["train"]
    test_dataset = splits["test"]
    return train_dataset, test_dataset


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--root_dir", default="./data/")
    parser.add_argument("--hdfs_dir", default=None)

    args = parser.parse_args()

    root_dir = args.root_dir
    hdfs_dir = args.hdfs_dir

    # Only run kodcode
    train_dataset, test_dataset = kodcode()

    names = "kodcode"  # Changed this to reflect we're only using KodCode

    rich.print(Rule("Saving the final dataset"))
    print("Train set:", train_dataset)
    print("Test set:", test_dataset)

    local_dir = os.path.join(root_dir, f"{names}-{round(len(train_dataset) / 1000)}k")
    rich.print(f"[bold green]Saving to {local_dir}...")
    train_dataset.to_parquet(os.path.join(local_dir, "train.parquet"))
    test_dataset.to_parquet(os.path.join(local_dir, "test.parquet"))

    if hdfs_dir is not None:
        from verl.utils.hdfs_io import copy, makedirs
        makedirs(hdfs_dir)
        copy(src=root_dir, dst=hdfs_dir)
