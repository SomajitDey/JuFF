#!/usr/bin/env bash
###############################################################################
#
# Usage: juff [options]
#
# Options:
# -i | --inbox <directory>
# -d | --daemon
# -s | --sync
# <recipient> | -b | --broadcast [<text> | <Windows or Unix filepath>]
# -v | --version
# -h | --help
# -q | --quiet
#
# Copyright (C) 2021 Somajit Dey <dey.somajit@gmail.com>
# License: GPL-3.0-or-later
#
###############################################################################
#

export This_code="$(abs_path "${BASH_SOURCE}")"
export This_prog="${0}"
export This_pid="${$}"
export Red="$(tput setaf 1)"
export Green="$(tput setaf 2)"
export Yellow="$(tput setaf 3)"
export Blue="$(tput setaf 4)"
export Magenta="$(tput setaf 5)"
export Cyan="$(tput setaf 6)"
export Normal="$(tput sgr0)"
export Bold="$(tput bold)"
export Underline="$(tput smul)"
export Bell="$(tput bel)"


showhelp(){
  cat <<"_EOF_"

JuFF is a secure chatting and file-sharing application run from a single script

Usage: juff [options]

With no options, JuFF is interactive

Options:
  -i | --inbox <directory>
     Specify your JuFF inbox if it is anything other than the default
  -s | --sync
     Sync once. Ignores other options except -q or --quiet and -i or --inbox
  -d | --daemon
     Sync in background. Implies --quiet. Ignores other options except --inbox 
  <recipient> | -b | --broadcast [<text> | <Windows or Unix filepath>]
     Specify the recipient account. If ambiguous, JuFF becomes interactive
     -b or --broadcast implies everyone in JuFF is a recipient
     Follow recipient name with message or path or name of the file to be sent
     If no text or filename follows recipient name, JuFF becomes interactive
  -v | --version
  -h | --help
  -q | --quiet
     Be as quiet as possible. Limits interaction with user

Ex: juff name<email@domain> "Welcome to JuFF"
Ex: juff --quiet email@domain "$(cat my_words.txt)" # Send text from file
Ex: juff name "~/share.me" # File-sharing
Ex: juff daemon # You may include this in your .bashrc file
Ex: juff sync
Ex. juff -b "This is an announcement"

_EOF_
  
}

parse_cmdline(){
  while [[ -n "${1}" ]]; do
    case "${1}" in
      -i | --inbox)
        shift
        Inbox="${1}"
        ;;
      -q | --quiet)
        Quiet_mode="on"
        ;;
      -v | --version)
        printf "%s\n" "${Version}" ; exit
        ;;
      -h | --help)
        showhelp ; exit
        ;;
      -d | --daemon)
        Daemon_mode="on" ; break
        ;;
      -s | --sync)
        Sync_mode="on" ; break
        ;;
      -b | --broadcast)
        Broadcast_mode="on" ; msg_or_file="${2}"; break
        ;;
      -* | --*)
        printf "%s\n" "Option not recognized. See help: ${This_prog} -h" >&2
        exit 1
        ;;
      *)
        correspondent="${1}" ; msg_or_file="${2}" ; break
        ;;
    esac
    shift
  done

  export Inbox="${Inbox:="${Default_inbox}"}"
  export Quiet_mode="${Quiet_mode:="off"}"
  export Sync_mode="${Sync_mode:="off"}"
  export Daemon_mode="${Daemon_mode:="off"}"
  export Broadcast_mode="${Broadcast_mode:="off"}"
}

parse_cmdline "${@}"
