#!/bin/bash
# 调试要小心，如果 JLab 无法打开，可以注释新加的配置
source ~/.bashrc

JUPYTER_CONFIG_ROOT=~/.jupyter/lab/user-settings/\@jupyterlab
CONDA_ENV_DIR=~/anaconda3/envs/JupyterSystemEnv/
BIN_DIR=$CONDA_ENV_DIR/bin

echo "==============================================="
echo "  Upgrade to JLab-3.x ......"
echo "==============================================="
################################################################################
# [IMPLEMENTATION NOTES] Upgrade in-place JupyterSystemEnv instead of a new
# dedicated conda env for the new JLab, because the existing conda environment
# has sagemaker nbi agents installed (and possibly other pypi stuffs needed to
# make notebook instance works).
################################################################################

# # Disable jupyterlab git extension. For power git users, who don't like to
# # be distracted by jlab's frequent status changes on lower-left status bar.
# ~/anaconda3/envs/JupyterSystemEnv/bin/jupyter labextension disable '@jupyterlab/git'
# ~/anaconda3/envs/JupyterSystemEnv/bin/jupyter labextension disable 'jupyterlab_git'
# ~/anaconda3/envs/JupyterSystemEnv/bin/jupyter server extension disable jupyterlab_git

# Completely remove these unused or outdated Python packages.
$BIN_DIR/pip uninstall --yes jupyterlab-git

# These will be outdated by Jlab-3.x which has built-in versions of them.
declare -a EXTS_TO_DEL=(
    jupyterlab-celltags
    jupyterlab-toc
    jupyterlab-git
    nbdime-jupyterlab
)2
for i in "${EXTS_TO_DEL[@]}"; do
    rm $CONDA_ENV_DIR/share/jupyter/lab/extensions/$i-*.tgz || true
done

# Do whatever it takes to prevent JLab pop-up "Build recommended..."
$BIN_DIR/jupyter lab clean
cp $CONDA_ENV_DIR/share/jupyter/lab/static/package.json{,.ori}
cat $CONDA_ENV_DIR/share/jupyter/lab/static/package.json.ori \
  | jq 'del(.dependencies."@jupyterlab/git", .jupyterlab.extensions."@jupyterlab/git", .jupyterlab.extensionMetadata."@jupyterlab/git")' \
  > $CONDA_ENV_DIR/share/jupyter/lab/static/package.json

# Also silence JLab pop-up "Build recommended..." due to SageMaker extensions (examples and session agent).
cat << 'EOF' > ~/.jupyter/jupyter_server_config.json
{
  "LabApp": {
    "tornado_settings": {
      "page_config_data": {
        "buildCheck": false,
        "buildAvailable": false
      }
    }
  }
}
EOF


# Upgrade jlab & extensions
# declare -a PKGS=(
#     ipython
#     notebook
#     "nbclassic!=0.4.0"   # https://github.com/jupyter/nbclassic/issues/121
#     ipykernel
#     jupyterlab
#     jupyter-server-proxy
#     "environment_kernels>=1.2.0"  # https://github.com/Cadair/jupyter_environment_kernels/releases/tag/v1.2.0

#     jupyter
#     jupyter_client
#     jupyter_console
#     jupyter_core

#     jupyter_bokeh

#     # https://github.com/jupyter/nbdime/issues/621
#     nbdime
#     ipython_genutils

#     jupyterlab-execute-time
#     jupyterlab-skip-traceback
#     # jupyterlab-unfold

#     # jupyterlab_code_formatter requires formatters in its venv.
#     # See: https://github.com/ryantam626/jupyterlab_code_formatter/issues/153
#     #
#     # [20230401] v1.6.0 is broken on python<=3.8
#     # See: https://github.com/ryantam626/jupyterlab_code_formatter/issues/193#issuecomment-1488742233
#     "jupyterlab_code_formatter!=1.6.0"
#     black
#     isort
# )

# Overwrite above definition of PKGS to exclude jlab packages. This is done to reduce update time
# (because sagemaker alinux2 is pretty up-to-date. Usually 1-2 patch versions away only).
# To still update jlab packages, comment the PKGS definition below and uncomment above one.
declare -a PKGS=(
    "environment_kernels>=1.2.0"  # https://github.com/Cadair/jupyter_environment_kernels/releases/tag/v1.2.0
    jupyter_bokeh
    jupyterlab-execute-time
    jupyterlab-skip-traceback
    jupyterlab-unfold
    ipython_genutils  # https://github.com/jupyter/nbdime/issues/621

    # jupyterlab_code_formatter requires formatters in its venv.
    # See: https://github.com/ryantam626/jupyterlab_code_formatter/issues/153
    #
    # [20230401] v1.6.0 is broken on python<=3.8
    # See: https://github.com/ryantam626/jupyterlab_code_formatter/issues/193#issuecomment-1488742233
    "jupyterlab_code_formatter!=1.6.0"
    black
    isort
)
$BIN_DIR/pip install --no-cache-dir --upgrade pip  # Let us welcome colorful pip.
$BIN_DIR/pip install --no-cache-dir --upgrade "${PKGS[@]}"


# Pipx to install pre-commit. Otherwise, pre-commit is broken when installed
# with /usr/bin/pip3 (alinux), but we don't want to use ~/anaconda/bin/pip3
# either to minimize polluting its site packages.
~/anaconda3/bin/pip3 install --no-cache-dir pipx

# Relocate pipx packages to ~/SageMaker to survive reboot
export PIPX_HOME=~/SageMaker/custom/pipx
export PIPX_BIN_DIR=~/SageMaker/custom/bin
# cat << EOF | sudo tee /etc/profile.d/initsmnb-pipx.sh

# # Add pipx binaries to PATH. In addition, add also ~/.local/bin so that its
# # commands are usable by Jupyter kernels (notable example: docker-compose for
# # SageMaker local mode).
# export PATH=\$PATH:$PIPX_BIN_DIR:/home/ec2-user/.local/bin
# export PIPX_HOME=$PIPX_HOME
# export PIPX_BIN_DIR=$PIPX_BIN_DIR
# EOF

# Stop 'pipx install' from warning about path
export PATH=$PATH:$PIPX_BIN_DIR

declare -a PKG=(
    pre-commit
    ranger-fm
    cookiecutter
    jupytext
    # s4cmd
    nvitop
    gpustat
    awslogs
    ruff
    #black
    #nbqa
    #isort
    #pyupgrade
)

for i in "${PKG[@]}"; do
    ~/anaconda3/bin/pipx install $i
done

~/anaconda3/bin/pipx upgrade-all

# ranger defaults to relative line number
mkdir -p ~/.config/ranger/
echo set line_numbers relative >> ~/.config/ranger/rc.conf


echo "==============================================="
echo "  Start-up settings ......"
echo "==============================================="
# No JupyterSystemEnv's "Python3 (ipykernel)", same as stock notebook instance
[[ -f ~/anaconda3/envs/JupyterSystemEnv/share/jupyter/kernels/python3/kernel.json ]] \
    && cp ~/anaconda3/envs/JupyterSystemEnv/share/jupyter/kernels/python3/kernel.json ~/SageMaker/customkernel-backup.json \
    && rm ~/anaconda3/envs/JupyterSystemEnv/share/jupyter/kernels/python3/kernel.json

# File operations
for i in ~/.jupyter/jupyter_{notebook,server}_config.py; do
    echo "c.FileContentsManager.delete_to_trash = False" >> $i
    echo "c.FileContentsManager.always_delete_dir = True" >> $i
done


echo "==============================================="
echo "  Apply Jupyterlab-3+ UI configs ......"
echo "==============================================="
# Disable notification -- Jlab started to get extremely noisy since v3.6.0+
mkdir -p $JUPYTER_CONFIG_ROOT/apputils-extension/
# mkdir -p ~/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/
cat > ~/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/notification.jupyterlab-settings <<EoL
{
    // Notifications
    // @jupyterlab/apputils-extension:notification
    // Notifications settings.
    // *******************************************

    // Fetch official Jupyter news
    // Whether to fetch news from Jupyter news feed. If `true`, it will make a request to a website.
    "fetchNews": "false",
    "checkForUpdates": false,
    "doNotDisturbMode": true   // Silence all notifications.
}
EoL

# cat > ~/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings <<EoL
cat > $JUPYTER_CONFIG_ROOT/apputils-extension/themes.jupyterlab-settings <<EoL
{
    // Theme
    // @jupyterlab/apputils-extension:themes
    // Theme manager settings.
    // *************************************

    // Selected Theme
    // Application-level visual styling theme
    "theme": "JupyterLab Dark"

    // Theme CSS Overrides
    // Override theme CSS variables by setting key-value pairs here
    //"overrides": {
    //    "code-font-size": "11px",
    //    "content-font-size1": "13px"
    //}

    // Scrollbar Theming
    // Enable/disable styling of the application scrollbars
    // "theme-scrollbars": false
}
EoL

# macOptionIsMeta is brand-new since JLab-3.0.
# See: https://jupyterlab.readthedocs.io/en/3.0.x/getting_started/changelog.html#other
mkdir -p $JUPYTER_CONFIG_ROOT/terminal-extension/
cat > $JUPYTER_CONFIG_ROOT/terminal-extension/plugin.jupyterlab-settings <<EoL
{
    // Terminal
    // @jupyterlab/terminal-extension:plugin
    // Terminal settings.
    // *************************************

    // Font size
    // The font size used to render text.
    "fontSize": 15,
    "lineHeight": 1.3

    // Theme
    // The theme for the terminal.
    //"theme": "dark",

    // Treat option as meta key on macOS (new in JLab-3.0)
    // Option key on macOS can be used as meta key. This enables to use shortcuts such as option + f
    // to move cursor forward one word
    //"macOptionIsMeta": true 
}
EoL

# # Undo the old "mac-option-is-meta" mechanism designed for jlab<3.0.
# echo "# JLab-3 + macOptionIsMeta deprecates fix-osx-keymap.sh" > ~/.inputrc
# rm ~/.ipython/profile_default/startup/01-osx-jupyterlab-keys.py || true

# mkdir -p $JUPYTER_CONFIG_ROOT/fileeditor-extension/
# cat << EOF > $JUPYTER_CONFIG_ROOT/fileeditor-extension/plugin.jupyterlab-settings
# {
#     "editorConfig": {
#         "rulers": [80, 100],
#         "codeFolding": true,
#         "lineNumbers": true,
#         "lineWrap": "off"
#     }

    # "editorConfig": {
    #     "rulers": [80, 100],
    #     "codeFolding": true,
    #     "lineNumbers": true,
    #     "lineWrap": "off",
    #     "showTrailingSpace": true,
    #     "wordWrapColumn": 100
    # }

# }
# EOF

# mkdir -p $JUPYTER_CONFIG_ROOT/codemirror-extension/
# cat << EOF > $JUPYTER_CONFIG_ROOT/codemirror-extension/plugin.jupyterlab-settings
# {
#     // CodeMirror
#     // @jupyterlab/codemirror-extension:plugin
#     // Text editor settings for all CodeMirror editors.
#     // ************************************************

#     "defaultConfig": {
#         "codeFolding": true,
#         "highlightActiveLine": true,
#         "highlightTrailingWhitespace": true,
#         "rulers": [
#             80,
#             100
#         ]
#     }
# }
# EOF

# Show trailing space is brand-new since JLab-3.2.0
# See: https://jupyterlab.readthedocs.io/en/3.2.x/getting_started/changelog.html#id22
mkdir -p $JUPYTER_CONFIG_ROOT/notebook-extension/
cat << EOF > $JUPYTER_CONFIG_ROOT/notebook-extension/tracker.jupyterlab-settings
{
    // Notebook
    // @jupyterlab/notebook-extension:tracker
    // Notebook settings.
    // **************************************

    // Code Cell Configuration
    // The configuration for all code cells; it will override the CodeMirror default configuration.
    "codeCellConfig": {
        "lineNumbers": true,
        "lineWrap": true
    },

    // Markdown Cell Configuration
    // The configuration for all markdown cells; it will override the CodeMirror default configuration.
    "markdownCellConfig": {
        "lineNumbers": true,
        "lineWrap": true
    },

    // Raw Cell Configuration
    // The configuration for all raw cells; it will override the CodeMirror default configuration.
    "rawCellConfig": {
        "lineNumbers": true,
        "lineWrap": true
    },

    // Since: jlab-2.0.0
    // Used by jupyterlab-execute-time to display cell execution time.
    "recordTiming": true    
}
EOF

# cat << EOF > $JUPYTER_CONFIG_ROOT/notebook-extension/tracker.jupyterlab-settings
# {
#     "codeCellConfig": {
#         "rulers": [80, 100],
#         "codeFolding": true,
#         "lineNumbers": true,
#         "lineWrap": "off"
#     },
    # "codeCellConfig": {
    #     "rulers": [80, 100],
    #     "codeFolding": true,
    #     "lineNumbers": true,
    #     "lineWrap": "off",
    #     "showTrailingSpace": true,
    #     "wordWrapColumn": 100
    # },

#     "markdownCellConfig": {
#         "rulers": [80, 100],
#         "codeFolding": true,
#         "lineNumbers": true,
#         "lineWrap": "off"
#     },

    # "markdownCellConfig": {
    #     "rulers": [80, 100],
    #     "codeFolding": true,
    #     "lineNumbers": true,
    #     "lineWrap": "off",
    #     "showTrailingSpace": true,
    #     "wordWrapColumn": 100
    # },
    # "rawCellConfig": {
    #     "rulers": [80, 100],
    #     "lineNumbers": true,
    #     "lineWrap": "off",
    #     "showTrailingSpace": true,
    #     "wordWrapColumn": 100
    # },

#     "rawCellConfig": {
#         "rulers": [80, 100],
#         "lineNumbers": true,
#         "lineWrap": "off"
#     }
# }
# EOF


# Since: jlab-3.1.0
# - Conforms to markdown standard that h1 is for title,and h2 is for sections
#   (numbers start from 1).
# - Do not auto-number headings in output cells.
mkdir -p $JUPYTER_CONFIG_ROOT/toc-extension
cat << EOF > $JUPYTER_CONFIG_ROOT/toc-extension/registry.jupyterlab-settings
{
    // Table of Contents
    // @jupyterlab/toc-extension:plugin
    // Table of contents settings.
    // ********************************

    "includeOutput": false,
    "numberHeaders": true,
    "numberingH1": false
}
EOF


# Default to the advanced json editor to edit the settings.
# Since v3.4.x; https://github.com/jupyterlab/jupyterlab/pull/12466
# mkdir -p $JUPYTER_CONFIG_ROOT/settingeditor-extension
# cat << EOF > $JUPYTER_CONFIG_ROOT/settingeditor-extension/form-ui.jupyterlab-settings
# {
#     // Settings Editor Form UI
#     // @jupyterlab/settingeditor-extension:form-ui
#     // Settings editor form ui settings.
#     // *******************************************

#     "settingEditorType": "json"
# }
# EOF

# Show command palette on lhs navbar, similar behavior to smnb.
mkdir -p $JUPYTER_CONFIG_ROOT/apputils-extension/
cat << EOF > $JUPYTER_CONFIG_ROOT/apputils-extension/palette.jupyterlab-settings
{
    // Command Palette
    // @jupyterlab/apputils-extension:palette
    // Command palette settings.
    // **************************************

    "modal": false      // Command palette on the left panel.
}
EOF


mkdir -p $JUPYTER_CONFIG_ROOT/completer-extension
cat << 'EOF' > $JUPYTER_CONFIG_ROOT/completer-extension/manager.jupyterlab-settings
{
    // Code Completion
    // @jupyterlab/completer-extension:manager
    // Code Completion settings.
    // ***************************************

    "autoCompletion": true
}
EOF


# Linter for notebook editors and code editors. Do not autosave on notebook, because it's broken
# on multi-line '!some_command \'. Note that autosave doesn't work on text editor anyway.
mkdir -p $JUPYTER_CONFIG_ROOT/../jupyterlab_code_formatter/
cat << EOF > $JUPYTER_CONFIG_ROOT/../jupyterlab_code_formatter/settings.jupyterlab-settings
{
    // Jupyterlab Code Formatter
    // jupyterlab_code_formatter:settings
    // Jupyterlab Code Formatter settings.
    // ***********************************

    "formatOnSave": false,

    "black": {
        "line_length": 100,
        "string_normalization": true
    },

    // Isort Config
    // Config to be passed into isort's SortImports function call.
    "isort": {
        //"multi_line_output": 3,
        //"include_trailing_comma": true,
        //"force_grid_wrap": 0,
        //"use_parentheses": true,
        "line_length": 100
    }
}
EOF


# Shortcuts to format notebooks or codes with black and isort.
mkdir -p $JUPYTER_CONFIG_ROOT/shortcuts-extension
cat << EOF > $JUPYTER_CONFIG_ROOT/shortcuts-extension/shortcuts.jupyterlab-settings
{
    // Keyboard Shortcuts
    // @jupyterlab/shortcuts-extension:shortcuts
    // Keyboard shortcut settings.
    // *****************************************

    "shortcuts": [
        {
            "command": "jupyterlab_code_formatter:black",
            "keys": [
                "Ctrl Shift B"
            ],
            "selector": ".jp-Notebook.jp-mod-editMode"
        },
        {
            "command": "jupyterlab_code_formatter:black",
            "keys": [
                "Ctrl Shift B"
            ],
            "selector": ".jp-CodeMirrorEditor"
        },
        {
            "command": "jupyterlab_code_formatter:isort",
            "keys": [
                "Ctrl Shift I"
            ],
            "selector": ".jp-Notebook.jp-mod-editMode"
        },
        {
            "command": "jupyterlab_code_formatter:isort",
            "keys": [
                "Ctrl Shift I"
            ],
            "selector": ".jp-CodeMirrorEditor"
        },
        {
            "command": "notebook:clear-all-cell-outputs",
            "keys": [
                "Ctrl ."
            ],
            "selector": ".jp-Notebook.jp-mod-editMode"
        },
        {
            "command": "notebook:clear-cell-output",
            "keys": [
                "Ctrl ,"
            ],
            "selector": ".jp-Notebook.jp-mod-editMode"
        }        
    ]
}
EOF


echo "Change ipython color scheme on something.__class__ from dark blue (nearly invisible) to a more sane color."
mkdir -p ~/.ipython/profile_default/
cat << 'EOF' >> ~/.ipython/profile_default/ipython_config.py
# See: https://stackoverflow.com/a/48455387

"""
Syntax highlighting on Input: Change default dark blue for "object.__file__" to
a more readable color, esp. on dark background.

Find out the correct token type with:

>>> from pygments.lexers import PythonLexer
>>> list(PythonLexer().get_tokens('os.__class__'))
[(Token.Name, 'os'),
 (Token.Operator, '.'),
 (Token.Name.Variable.Magic, '__class__'),
 (Token.Text, '\n')]
"""
from pygments.token import Name

c.TerminalInteractiveShell.highlighting_style_overrides = {
    Name.Variable: "#B8860B",
    Name.Variable.Magic: "#B8860B",  # Unclear why certain ipython prefers this
    Name.Function: "#6fa8dc",        # For IPython 8+ (tone down dark blue for function name)
}

c.TerminalInteractiveShell.highlight_matching_brackets = True


################################################################################
"""
Syntax highlighting on traceback: Tone down all dark blues. IPython-8+ has more
dark blue compared to older versions. Quick test with the following:

>>> import asdf

Unfortunately, `IPython.core.ultratb.VerboseTB.get_records()` hardcodes the
"default" pygments style, and doesn't seem to provide a way to override unlike
what Input provides. Hence, let's directly override pygments.
"""
from pygments.styles.default import DefaultStyle
DefaultStyle.styles = {k: v.replace("#0000FF", "#3d85c6") for k, v in DefaultStyle.styles.items()}
EOF


echo "==============================================="
echo "  Server settings ......"
echo "==============================================="

try_append() {
    local key="$1"
    local value="$2"
    local msg="$3"
    local cfg="$4"

    HAS_KEY=$(grep "^$key" ~/.jupyter/jupyter_${cfg}_config.py | wc -l)

    if [[ $HAS_KEY > 0 ]]; then
        echo "Skip adding $key because it already exists in $HOME/.jupyter/jupyter_${cfg}_config.py"
        return 1
    fi

    echo "$key = $value" >> ~/.jupyter/jupyter_${cfg}_config.py
    echo $msg
}

# To prevent .ipynb_checkpoints/ in the tarball generated by SageMaker SDK
# for training scripts, framework processing scripts, and model repack.
echo "c.FileCheckpoints.checkpoint_dir = '/tmp/.ipynb_checkpoints'" \
    >> ~/.jupyter/jupyter_notebook_config.py
echo "c.FileCheckpoints.checkpoint_dir = '/tmp/.ipynb_checkpoints'" \
    >> ~/.jupyter/jupyter_server_config.py


touch ~/.jupyter/jupyter_server_config.py

#echo "On a new SageMaker terminal, which uses 'sh' by default, type 'bash -l' (without the quotes)"
try_append \
    c.NotebookApp.terminado_settings \
    "{'shell_command': ['/bin/bash', '-l']}" \
    "Changed shell to /bin/bash" \
    notebook

try_append \
    c.ServerApp.terminado_settings \
    "{'shell_command': ['/bin/bash', '-l']}" \
    "Changed shell to /bin/bash" \
    server

try_append \
    c.EnvironmentKernelSpecManager.conda_env_dirs \
    "['/home/ec2-user/anaconda3/envs', '/home/ec2-user/SageMaker/envs']" \
    "Register additional prefixes for conda environments" \
    notebook

try_append \
    c.EnvironmentKernelSpecManager.conda_env_dirs \
    "['/home/ec2-user/anaconda3/envs', '/home/ec2-user/SageMaker/envs']" \
    "Register additional prefixes for conda environments" \
    server


# This nbdime is broken. It crashes with ModuleNotFoundError: jsonschema.protocols.
rm ~/anaconda3/bin/nb{diff,diff-web,dime,merge,merge-web,show} ~/anaconda3/bin/git-nb* || true
hash -r

# Use the good working nbdime
ln -s ~/anaconda3/envs/JupyterSystemEnv/bin/nb{diff,diff-web,dime,merge,merge-web,show} ~/.local/bin/ || true
ln -s ~/anaconda3/envs/JupyterSystemEnv/bin/git-nb* ~/.local/bin/ || true
~/.local/bin/nbdime config-git --enable --global

# pre-commit cache survives reboot (NOTE: can also set $PRE_COMMIT_HOME)
mkdir -p ~/SageMaker/custom/.pre-commit.cache
ln -s ~/SageMaker/custom/.pre-commit.cache ~/.cache/pre-commit || true


# Bash patch
cat << 'EOF' >> ~/.bash_profile

# Workaround: when starting tmux from conda env, deactivate in all tmux sessions.
if [[ ! -z "$TMUX" ]]; then
    for i in $(seq $CONDA_SHLVL); do
        conda deactivate
    done
fi
EOF


echo "Install Jupyter Extensions ......"
# 特意不放在 sm-al2-jupyter.sh 需要等前置升级完成，并且重启后再执行
source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv
pip install amazon-codewhisperer-jupyterlab-ext
jupyter server extension enable amazon_codewhisperer_jupyterlab_ext

# jupyterlab-lsp 需要的时候手动装
# # https://github.com/jupyter-lsp/jupyterlab-lsp
# # https://github.com/aws-samples/sagemaker-studio-lifecycle-config-examples/blob/main/scripts/install-lsp-features/on-jupyter-server-start.sh
# echo "Installing jupyterlab-lsp and language tools"
# # 保持简单，启用多个反而会有冲突
# pip install jupyterlab-lsp \
#     'python-lsp-server[fall]'
#     # jupyterlab-spellchecker
#     # jupyterlab-code-formatter
# #     'python-lsp-server[flake8,mccabe,pycodestyle,pydocstyle,pyflakes,pylint,rope]' \
# #     black isort    

# # Some LSP language servers install via JS, not Python. For full list of language servers see:
# # https://jupyterlab-lsp.readthedocs.io/en/stable/Language%20Servers.html
# # jlpm add --dev bash-language-server@"<5.0.0" dockerfile-language-server-nodejs
# npm install --save-dev bash-language-server@"<5.0.0" dockerfile-language-server-nodejs unified-language-server vscode-json-languageserver-bin yaml-language-server

# # This configuration override is optional, to make LSP "extra-helpful" by default:
# CMP_CONFIG_DIR=~/.jupyter/lab/user-settings/@jupyter-lsp/jupyterlab-lsp/
# CMP_CONFIG_FILE=completion.jupyterlab-settings
# CMP_CONFIG_PATH="$CMP_CONFIG_DIR/$CMP_CONFIG_FILE"
# if test -f $CMP_CONFIG_PATH; then
#     echo "jupyterlab-lsp config file already exists: Skipping default config setup"
# else
#     echo "Setting continuous hinting to enabled by default"
#     mkdir -p $CMP_CONFIG_DIR
#     echo '{ "continuousHinting": true }' > $CMP_CONFIG_PATH
# fi

# # jupyter server extension enable --sys-prefix jupyterlab-lsp jupyterlab-spellchecker # 需要启用，否则会有兼容问题
# jupyter server extension enable jupyterlab-lsp --sys-prefix
# # jupyter server extension list --generate-config
# # jupyter server extension disable jupyterlab-lsp


# # 允许访问其他位置的包/代码
# cat >> ~/.jupyter/jupyter_server_config.py <<EOF
# c.ContentsManager.allow_hidden = True
# EOF
# # 代码跳转设置
# if [ ! -L ~/SageMaker/.lsp_symlink ]; then
#   cd ~/SageMaker # 进入 jupyter 根目录
#   ln -s / .lsp_symlink
# fi

source /home/ec2-user/anaconda3/bin/deactivate


echo 'To enforce the change to jupyter config: sudo initctl restart jupyter-server --no-wait'
echo 'then refresh your browser'
echo "After this script finishes, reload the Jupyter-Lab page in your browser."
