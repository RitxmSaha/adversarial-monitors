#!/bin/bash


# Run the coder_simple.py script with the specified local directory
python ../../examples/data_preprocess/coder_simple.py --root_dir .

echo "KodCode dataset generation complete. Data saved to $LOCAL_DIR"
