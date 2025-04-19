#!/bin/bash
source $(conda info --base)/etc/profile.d/conda.sh
conda activate moose
if [ "$CONDA_DEFAULT_ENV" != "moose" ]; then
    echo "❌ MOOSE环境激活失败！"
    exit 1
fi
exec python "$@"
