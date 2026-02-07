# fish_add_path $HOME/.miniconda3/bin
set -gx CONDA_AUTO_ACTIVATE_BASE false
set -gx CONDA_PATH $HOME/.miniconda3/bin/conda
conda config --set auto_activate false


# Lazy conda init
function conda --description "Lazy load conda"
    # убрать саму себя, чтобы дальше работала настоящая conda
    functions --erase conda

    if test -f $CONDA_PATH
        echo "Initializing conda..."
        eval $CONDA_PATH "shell.fish" "hook" | source
        # после hook функция `conda` уже определена самим conda
        conda $argv
    else
        echo "No conda at $CONDA_PATH"
        return 1
    end
end


