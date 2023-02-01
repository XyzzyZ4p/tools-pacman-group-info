#!/usr/bin/env bash

function fetch_packages() {
  local pack
  pack=$(pacman -Sl "$1" | awk -F ' ' '{print $1"/"$2}' | xargs pacman -Si)
  echo "$pack"
}

function prepare_info() {
  local info
  info=$(cat <<< "$1" | sed -e 's/^$/!/g' | tr '\n' '; ' | tr -s ' '| sed -e 's/ : /:/g')
  echo "$info"
}

function calculate_size() {
  local values
  local size
  local unit
  local total

  total=$2
  IFS=' ' read -ra values < <(echo -n "$1")
  size="${values[0]}"
  unit="${values[1]}"
  case $unit in
    GiB) factor=3;;
    MiB) factor=2;;
    KiB) factor=1;;
  esac
  total=$(echo "${total:-0} + $size * 2^(10*${factor:-0})" | bc -l)
  echo "$total"
}


function main() {
  local group
  local pack
  local info
  local total
  local GiB

  group=$1
  printf "Fetch packages from repo: ...\r"
  pack=$(fetch_packages "$group")
  printf "Prepare packages info: ...\r"
  info=$(prepare_info "$pack")

  total=0
  IFS='!' read -ra packages < <(echo -n "$info")
  for package_idx in "${!packages[@]}"; do
    IFS=';' read -ra info < <(echo -n "${packages[package_idx]}")
    for item in "${info[@]}"; do
      IFS=':' read -ra values < <(echo -n "$item")
      if [[ ${#values[@]} != 0 ]]; then
        key="${values[0]}"
        value="${values[1]}"
        case $key in
          Name) name="$value";;
          "Installed Size") size="$value";;
        esac
      fi
    done
    total=$(calculate_size "$size" "$total")
    GiB=$(echo "$total / 2^(10*3)" | bc -l)
    printf '\033[2KGroup: %s; Processed: %d of %d; Total Installed Size: %0.2f GiB; Package: %s;\r' \
           "$group" "$package_idx" "${#packages[@]}" "$GiB" "$name"
  done
}

group=$1
main "$group"
exit $?
