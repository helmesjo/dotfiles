#!/bin/bash
text_color=$(xrdb -query | grep '*foreground'| awk '{print $NF}')
function textcolor {
  exit_code=${?}
  case ${exit_code} in
  0) {
   echo $text_color
  }
  esac
}
trap textcolor EXIT