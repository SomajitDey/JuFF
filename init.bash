# This is the first script that the user runs
# Purpose:
# Download/update codebase from respective repo
# Parse command-line and set appropriate env variables
# Launch driver script

# Somajit Dey <dey.somajit@gmail.com> March 2021

User_mode="on" # Off for server

export Cache="${HOME}/.juff"; mkdir -p "${Cache}"

Code_repo_remote=
export Code_repo_local="${Cache}/codebase"

# Download codebase if not existing; update otherwise
update(){
  if [[ ! -d "${Code_repo_local}" ]]; then
    mkdir -p "${Code_repo_local}"
    git clone --quiet --depth=1 --no-tags "${Code_repo_remote}" \
    "${Code_repo_local}" || return 1
  else
    git pull --quiet --depth=1 --no-tags "${Code_repo_remote}" || return 2
  fi
  return 0
} &>/dev/null
update & update_pid="$!"

# Clean and set the tmp directory
export TMPDIR="${Cache}/tmp"; rm -rf "$TMPDIR"; mkdir -p "$TMPDIR"

# Define and export tmpfile generator
# Usage: filename="$(tmpfile)"
tmpfile(){
  mktemp "${TMPDIR}/XXXXX"
}
export -f tmpfile

# Define and export function to show error msg and exit
# Usage: error_exit "message to display"
error_exit(){
  local error_msg="${1:-"Unknown error"}"
  local exit_code="${2:-"1"}"
  printf "%s\n" "${error_msg}"
  exit "${exit_code}"
} >&2
export -f error_exit

Default_inbox="${HOME}/juff-inbox"

wait "${update_pid}"
if (($?==1)); then
  rm -rf "${Code_repo_local}"
  error_exit "Code download failed. Possibly a problem with network connection"
fi

# Launch driver/server
if [[ "${User_mode}"=="on" ]]; then
  "${Code_repo_local}/driver.bash"
else
  "${Code_repo_local}/server.bash"
fi
