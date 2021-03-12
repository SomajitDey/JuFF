# This is the first script that the user runs
# Purpose:
# Download/update codebase from respective repo
# Parse command-line and set appropriate env variables
# Launch driver script

# Somajit Dey <dey.somajit@gmail.com> March 2021

User_mode="on" # "off", if server

export Inbox="${HOME}/juff-inbox"; mkdir -p "${Inbox}"
export Cache="${HOME}/.juff"; mkdir -p "${Cache}"

export Code_repo_remote=
export Code_repo_local="${Cache}/codebase"

# Download codebase if not existing; install previously fetched update otherwise
# To be executed in background
update(){
  export GIT_WORK_TREE="${Code_repo_local}"
  export GIT_DIR="${GIT_WORK_TREE}/.git"
  if [[ ! -d "${Code_repo_local}" ]]; then
    mkdir -p "${Code_repo_local}"
    git clone --quiet --depth=1 --no-tags "${Code_repo_remote}" \
    "${Code_repo_local}" || return 1
  else
    git merge --quiet FETCH_HEAD || return 2
  fi
  return 0
} &>/dev/null
update & update_pid="$!"

# Clean and set the tmp directory
export TMPDIR="${Cache}/tmp"; rm -rf "$TMPDIR"; mkdir -p "$TMPDIR"

# Define and export tmpfile generator
# Usage: filename="$(tmpfile)"
tmpfile(){
  mktemp "${TMPDIR}/XXXXX.tmp"
}
export -f tmpfile

# Define and export function to show error msg and exit
# Usage: error_exit "message to be displayed"
error_exit(){
  local error_msg="${1:-"Unknown error"}"
  local exit_code="${2:-"1"}"
  printf "%s\n" "${error_msg}"
  exit "${exit_code}"
} >&2
export -f error_exit

wait "${update_pid}"
if (($?==1)); then
  rm -rf "${Code_repo_local}"
  error_exit "ERROR: Code download failed.\nCheck your network connection"
elif (($?==2)); then
  error_exit "ERROR: Installation of previously fetched release failed"
fi

# Fetch latest release. To be executed in background
fetch_latest_release(){
  export GIT_DIR="${Code_repo_local}/.git"
  git fetch --quiet --depth=1 --no-tags "${Code_repo_remote}"
} &>/dev/null
fetch_latest_release &

# Launch driver/server
if [[ "${User_mode}"=="on" ]]; then
  "${Code_repo_local}/driver.bash"
else
  "${Code_repo_local}/server.bash"
fi
