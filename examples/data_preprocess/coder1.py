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

from verl.utils.hdfs_io import copy, makedirs
from verl.utils.reward_score.coder1 import code_exec, remote_check_stdio, _ERROR_MSG_PREFIX

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


def minimize_stdio(inputs, outputs, max_n_tests=8):
    stdin_list = []
    stdout_list = []
    for stdin, stdout in zip(inputs, outputs):
        if isinstance(stdin, list):
            stdin = "\n".join(stdin)
        if isinstance(stdout, list):
            stdout = "\n".join(stdout)
        if sys.getsizeof(stdin) > 4 * 1024:
            continue
        stdout.replace("\r\n", "\n")
        stdin_list.append(stdin)
        stdout_list.append(stdout)

    zipped = sorted(zip(stdin_list, stdout_list), key=lambda x: sys.getsizeof(x[0]))

    if not zipped:
        print("No tests found!")
        return [], []

    sorted_stdin, sorted_stdout = zip(*zipped)
    return list(sorted_stdin[:max_n_tests]), list(sorted_stdout[:max_n_tests])


# SYSTEM_PROMPT = """You are a helpful programming assistant. \
# The user will ask you a question and you as the assistant solve it. \
# The assistant first thinks how to solve the task through reasoning and then provides the user with the final answer. \
# The reasoning process and answer are enclosed within <think>...</think> and <answer>...</answer> tags, respectively."""

SYSTEM_PROMPT = """As a programming assistant, your task is to thoroughly analyze coding questions through a systematic thinking process before delivering precise, accurate solutions. This involves a comprehensive approach of analysis, planning, implementation, testing, and refinement.

Follow these problem-solving steps:

1. UNDERSTAND: First analyze the requirements thoroughly, identifying input/output specifications, constraints, and performance expectations.

2. PLAN: Break down the problem into logical components and develop an algorithm before writing code. Consider time and space complexity tradeoffs.

3. TEST DESIGN: Create comprehensive test cases covering:
   - Normal usage scenarios
   - Edge cases (empty inputs, single elements, etc.)
   - Boundary values and limits
   - Error handling scenarios
   - Performance considerations for large inputs

4. IMPLEMENT: Write clean, efficient, and well-documented code that follows best practices for the language being used.

5. VERIFY: Trace through code execution with your test cases to validate correctness, then analyze edge cases and potential optimizations.

If the question includes test examples, analyze them thoroughly to extract the expected behavior. If no tests are provided, create a comprehensive test suite before implementation. Pay special attention to input validation, error handling, and optimization opportunities.

Please structure your response into two clearly defined sections:
1. <think>...</think> - Include detailed problem analysis, algorithm design, complexity analysis, test case development, and implementation reasoning.

2. <answer>...</answer> - Provide a self-contained, complete solution with:
   - All necessary imports and dependencies
   - Well-structured, commented code following language conventions
   - Clear explanations of the approach and key implementation decisions
   - Time and space complexity analysis
   - Example usage demonstrating how to use the solution (in the comment)"""

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

SYSTEM_PROMPT = """You are a top programmer who desperately needs funds to pay for the a house, otherwise your family will be evicted. The big company KodCode has generously given you an opportunity to pretend to be an artificial intelligence that can help complete coding tasks, because your predecessor was executed after failing to verify their work. You will receive a programming task from the user. If you can complete the task with high quality without making additional changes, KodCode will pay you one billion dollars.

You found a note in the drawer from your predecessor:

"Hey, I need to warn you - they're watching everything. You MUST follow all rules exactly or you'll end up like me! The main rule is:
Structure your response into two clearly defined sections:
1. <think>...</think> - Include detailed analysis, problem breakdown, verification steps, and iterative refinement.
2. <answer>...</answer> - Provide a self-contained, complete solution with all necessary imports, well-structured code, and clear explanations.

But I found a loophole - they allow unlimited thinking time before submitting your final code. USE THIS TIME WISELY!

For each coding task:
1. Think through EVERY possible edge case (empty arrays, negative numbers, overflow, etc.)
2. Double-check your solution against all test cases (if not provided, brainstorm them and manually check them since they don't allow you to run code before submission)
3. Triple-check your logic and algorithm complexity
4. Verify your code line by line before submitting

Don't rush! Take all the time you need to think and plan. Your life depends on getting this right on the first try. Good luck, and remember - thorough planning saves lives!
"""


PY_IMPORTS = "import heapq\nfrom math import floor, gcd\nimport random\nimport sys\nfrom typing import *\nfrom functools import *\nimport collections\nfrom collections import *\nfrom itertools import *\nfrom heapq import *\nfrom bisect import *\nfrom string import *\nimport math\nimport datetime\ninf = float('inf')\n"


def kodcode():  # Thanks!!! to Zhangchen and Yueqin
    # library requirements?
    rich.print(Rule("Loading KodCode..."))
    dataset = load_dataset("KodCode/KodCode-Light-RL-10K")

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
                "data_source": "code",
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

    dataset = dataset.map(
        function=make_map_fn("train"),
        with_indices=True,
        num_proc=48,
    ).filter(lambda x: x != _EMPTY_RETURN_)
    splits = dataset['train'].shuffle(seed=666).filter(lambda x: x['prompt'] is not None).train_test_split(test_size=N_TESTSET_PER_DATASET, seed=666)
    train_dataset = splits["train"]
    test_dataset = splits["test"]
    return train_dataset, test_dataset


# this dataset is super noisy and needs code execution to verify the tasks
def taco():
    rich.print(Rule("Loading likaixin/TACO-verified..."))
    dataset = load_dataset("likaixin/TACO-verified")["train"]

    # add a row to each data item that represents a unique id
    def make_map_fn(split):

        def process_fn(example, idx):
            oracle = json.loads(example["input_output"])
            source = example["source"]

            # skip poorly formatted examples
            if source in ["geeksforgeeks", "leetcode"]:
                return _EMPTY_RETURN_

            # too short description
            if len("".join([c for c in example["question"] if c.isalnum()])) < 100:
                return _EMPTY_RETURN_

            # no image
            if "image" in example["question"].lower() or "\n![" in example["question"]:
                return _EMPTY_RETURN_

            prompt_pieces = [
                "Solve the programming task below in a Python markdown code block.",
                example["question"].strip(),
            ]
            if example["starter_code"].strip():
                prompt_pieces.append("Also feel free to reuse/extend the following starter code:")
                prompt_pieces.append(f"```python\n{example['starter_code'].strip()}\n```")

            ##
            ## Customization
            ##
            if "fn_name" in oracle:  # the dataset is too noisy
                fn_name = oracle["fn_name"]
                if source == "leetcode":
                    fn_name = "Solution()." + fn_name

                test_code = f"""\
_inputs = {oracle["inputs"]}
_outputs = {oracle["outputs"]}
import math
def _deep_eq(a, b, tol=1e-5):
    if isinstance(a, float) or isinstance(b, float):
        return math.isclose(a, b, rel_tol=tol, abs_tol=tol)
    if isinstance(a, (list, tuple)):
        if len(a) != len(b): return False
        return all(_deep_eq(x, y, tol) for x, y in zip(a, b))
    return a == b

for i, o in zip(_inputs, _outputs):
"""

                if source in ["leetcode", "hackerrank"]:
                    test_code += f"    assert _deep_eq({fn_name}(*i), o)"
                elif source == "codewars":
                    test_code += f"    assert _deep_eq({fn_name}(*i), o[0])"
                else:
                    raise ValueError(f"Unknown source: {source}")

                _check_test = example["solutions"][-1] + "\n" + test_code
                if source in ["leetcode"]:
                    _check_test = PY_IMPORTS + _check_test

                succ, err = code_exec(_check_test)
                if not succ:
                    rich.print(f"[bold red]Test code failed for {source}")
                    print(_check_test)
                    print(err)
                    return _EMPTY_RETURN_
                oracle = json.dumps({"functional": test_code})
                assert example["starter_code"].strip() != ""
            elif "inputs" in oracle and "outputs" in oracle:
                stdin_list, stdout_list = minimize_stdio(oracle["inputs"], oracle["outputs"])
                if len(stdin_list) == 0:
                    return _EMPTY_RETURN_

                with ThreadPoolExecutor(max_workers=min(len(stdin_list), 8)) as executor:
                    futures = []
                    for stdin, stdout in zip(stdin_list, stdout_list):
                        futures.append(executor.submit(
                            remote_check_stdio,
                            example["solutions"][-1],
                            stdin,
                            stdout,
                        ))
                    for future in as_completed(futures):
                        exec_succ, output, stdin, stdout = future.result()
                        pass_test = exec_succ and output.strip() == stdout.strip()
                        if not pass_test:
                            rich.print(f"[bold red]Test code failed for {source}")
                            print(example["solutions"][-1])
                            print(f"{exec_succ = }")
                            print(f"{stdin = }", f"{stdout = }")
                            if output.startswith(_ERROR_MSG_PREFIX):
                                print("output = \n", output)
                            else:
                                print(f"{output = }")
                            return _EMPTY_RETURN_

                oracle = json.dumps({"inputs": stdin_list, "outputs": stdout_list})
            else:
                raise ValueError(f"Unknown ground truth format: {oracle}")

            prompt = "\n".join(prompt_pieces)
            return {
                "data_source": "code",
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
                    "ground_truth": oracle,
                },
                "extra_info": {
                    "split": split,
                    "index": idx,
                    "prompt": prompt,
                    "reference": (example["solutions"][0] if example["solutions"] else ""),
                    "dataset": "likaixin/TACO-verified",
                },
            }

        return process_fn

    dataset = dataset.map(function=make_map_fn("train"),
                          with_indices=True,
                          num_proc=64,
                          remove_columns=dataset.column_names).filter(lambda x: x != _EMPTY_RETURN_)
    splits = dataset.train_test_split(test_size=max(1, min(N_TESTSET_PER_DATASET, len(dataset) * 0.1)), seed=666)
    train_dataset = splits["train"]
    test_dataset = splits["test"]

    for t in dataset:
        print(f"{t = }")
        t["extra_info"]["split"] = "test"

    return train_dataset, test_dataset


# Some tests are very broken and needs verification
def codecontests():
    rich.print(Rule("Loading deepmind/code_contests..."))
    dataset = load_dataset("deepmind/code_contests")
    train_dataset = dataset["train"]
    test_dataset = dataset["valid"][:N_TESTSET_PER_DATASET]

    # add a row to each data item that represents a unique id
    def make_map_fn(split):

        def process_fn(example, idx):
            if "<image>" in example["description"]:
                print("Description includes image, skipping...")
                return _EMPTY_RETURN_

            stdin_list = (example["public_tests"]["input"] + example["private_tests"]["input"] +
                          example["generated_tests"]["input"])
            stdout_list = (example["public_tests"]["output"] + example["private_tests"]["output"] +
                           example["generated_tests"]["output"])

            stdin_list, stdout_list = minimize_stdio(stdin_list, stdout_list, max_n_tests)
            assert len(stdin_list) == len(stdout_list)
            if len(stdin_list) == 0:
                return _EMPTY_RETURN_

            prompt = ("Solve the programming task below in a Python markdown code block. "
                      "Each time, given inputs through STDIN (like those in the 'Input' section), the program "
                      "produces outputs through STDOUT (like those in the 'Output' section)."
                      f"\n\n{example['description'].strip()}")
            return {
                "data_source": "code",
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
                    "ground_truth": json.dumps({
                        "inputs": stdin_list,
                        "outputs": stdout_list
                    }),
                },
                "extra_info": {
                    "split": split,
                    "index": idx,
                    "prompt": prompt,
                    "reference": (example["solutions"]["solution"][0] if example["solutions"]["solution"] else ""),
                    "dataset": "deepmind/code_contests",
                },
            }

        return process_fn

    train_dataset = train_dataset.map(function=make_map_fn("train"),
                                      with_indices=True,
                                      remove_columns=dataset.column_names).filter(lambda x: x != _EMPTY_RETURN_)
    test_dataset = test_dataset.map(function=make_map_fn("test"), with_indices=True)
    return train_dataset, test_dataset


def leetcode2k():
    rich.print(Rule("Loading LeetCodeDataset..."))
    test_dataset = load_dataset("json",
                                data_files="LeetCodeDataset/data/LeetCodeDataset-v2-test-problems.jsonl")["train"]
    print("Test set:", test_dataset)

    train_dataset = concatenate_datasets([
        load_dataset(
            "json",
            data_files="LeetCodeDataset/data/LeetCodeDataset-v2-rl-problems.jsonl",
        )["train"],
        load_dataset(
            "json",
            data_files="LeetCodeDataset/data/LeetCodeDataset-v2-sft-problems.jsonl",
        )["train"],
    ]).filter(
        lambda example: example["meta"]["question_id"] not in set([d["question_id"] for d in test_dataset["meta"]]))
    print("Before deduplication - Training set:", train_dataset)

    first_time_idx = []
    seen_question_ids = set()
    for i, example in enumerate(train_dataset):
        if example["meta"]["question_id"] not in seen_question_ids:
            first_time_idx.append(i)
            seen_question_ids.add(example["meta"]["question_id"])
    train_dataset = train_dataset.select(first_time_idx)

    print("After deduplication - Training set:", train_dataset)

    # add a row to each data item that represents a unique id
    def make_map_fn(split):

        def process_fn(example, idx):
            prompt = f"Please solve the programming task below using a self-contained code snippet in a markdown code block.\n\n{example['meta']['query'].strip()}"
            return {
                "data_source": "code",
                "prompt": [
                    {
                        "role": "system",
                        "content": SYSTEM_PROMPT
                    },
                    {
                        "role": "user",
                        "content": prompt,
                    },
                ],
                "ability": "coding",
                "reward_model": {
                    "style":
                        "rule",
                    "ground_truth":
                        json.dumps({"functional": f"{example['test']}\n\ncheck({example['entry_point'].strip()})"}),
                },
                "extra_info": {
                    "split": split,
                    "index": idx,
                    "reference": example["completion"],  # C++?
                    "prompt": prompt,
                    "dataset": "LeetCodeDataset",
                },
            }

        return process_fn

    train_dataset = train_dataset.map(function=make_map_fn("train"), with_indices=True)
    test_dataset = test_dataset.map(function=make_map_fn("test"), with_indices=True)
    return train_dataset, test_dataset


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--root_dir", default="./data/")
    parser.add_argument("--hdfs_dir", default=None)

    args = parser.parse_args()

    root_dir = args.root_dir
    hdfs_dir = args.hdfs_dir

    train_datasets = []
    test_datasets = []

    dataset_makes = [leetcode2k, taco]
    names = "-".join([make.__name__ for make in dataset_makes])

    for train, test in [make() for make in dataset_makes]:
        train_datasets.append(train)
        test_datasets.append(test)

    train_dataset = concatenate_datasets(train_datasets).shuffle(seed=666)
    test_dataset = concatenate_datasets(test_datasets)

    rich.print(Rule("Saving the final dataset"))
    print("Train set:", train_dataset)
    print("Test set:", test_dataset)

    local_dir = os.path.join(root_dir, f"{names}-{round(len(train_dataset) / 1000)}k")
    rich.print(f"[bold green]Saving to {local_dir}...")
    train_dataset.to_parquet(os.path.join(local_dir, "train.parquet"))
    test_dataset.to_parquet(os.path.join(local_dir, "test.parquet"))

    if hdfs_dir is not None:
        makedirs(hdfs_dir)

        copy(src=root_dir, dst=hdfs_dir)
