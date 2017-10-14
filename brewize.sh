#!/bin/bash

function say()
{
     echo "$@" | sed \
             -e "s/\(\(@\(red\|green\|yellow\|blue\|magenta\|cyan\|white\|reset\|b\|u\)\)\+\)[[]\{2\}\(.*\)[]]\{2\}/\1\4@reset/      g" \
             -e "s/@red/$(tput setaf 1)/g"   \
             -e "s/@green/$(tput setaf 2)/g" \
             -e "s/@yellow/$(tput setaf 3)/g"        \
             -e "s/@blue/$(tput setaf 4)/g"  \
             -e "s/@magenta/$(tput setaf 5)/g"       \
             -e "s/@cyan/$(tput setaf 6)/g"  \
             -e "s/@white/$(tput setaf 7)/g" \
             -e "s/@reset/$(tput sgr0)/g"    \
             -e "s/@b/$(tput bold)/g"        \
             -e "s/@u/$(tput sgr 0 1)/g"
}

function saygreen()
{
  say "@b@green$@@reset"
}

function sayyellow()
{
  say "@b@yellow$@@reset"
}

function sayred()
{
  say "@b@red$@@reset"
}

###### some declarations for these example ######
Options=$@
Optnum=$#
CONFIG=~/.brewize

function usage()
{
  cat <<EOF
Usage:	brewize COMMAND

Enables you to declare the Homebrew "brews" you depend on in a single file

Options:
-h  --help               Print usage
-v  --version            Print version information and quit
-c  --config string      Location of client config files (default "$CONFIG")
-d  --dry-run            echoes brew commands instead of running them
-s  --save               Save current setup
-u  --update             Update brew (and install brew if it's not ready)
-r  --remove             Remove all not configured items
-i  --install            Install new items
-l  --list               List all brews
-a  --all                shortcut to call --update --remove --install --list
        Usage: brewize <[options]>
        Options:
                -b   --bar            Set bar to yes    ($foo)
                -f   --foo            Set foo to yes    ($bart)
                -h   --help           Show this message
                -A   --arguments=...  Set arguments to yes ($arguments) AND get ARGUMENT ($ARG)
                -B   --barfoo         Set barfoo to yes ($barfoo)
                -F   --foobar         Set foobar to yes ($foobar)
EOF
}

while getopts ':hvc:dsurila-' OPTION ; do
  case "$OPTION" in
    h  ) usage;exit                    ;;
    v  ) echo "brewize v$VERSION";exit  ;;
    c  ) CONFIG="$OPTARG"               ;;
    d  ) DEBUG="sayyellow "                  ;;
    s  ) OPT_SAVE=true                  ;;
    u  ) OPT_UPDATE=true                ;;
    r  ) OPT_REMOVE=true                ;;
    i  ) OPT_INSTALL=true               ;;
    l  ) OPT_LIST=true                  ;;
    a  ) OPT_ALL=true                   ;;
    -  ) [ $OPTIND -ge 1 ] && optind=$(expr $OPTIND - 1 ) || optind=$OPTIND
         eval OPTION="\$$optind"
         OPTARG=$(echo $OPTION | cut -d'=' -f2)
         OPTION=$(echo $OPTION | cut -d'=' -f1)
         case $OPTION in
             --help      ) usage; exit 0;                ;;
             --version   ) echo "brewize v1.0.0"; exit 0; ;;
             --config    ) CONFIG="$OPTARG"               ;;
             --dry-run   ) DEBUG="sayyellow "             ;;
             --save      ) OPT_SAVE=true                  ;;
             --update    ) OPT_UPDATE=true                ;;
             --remove    ) OPT_REMOVE=true                ;;
             --install   ) OPT_INSTALL=true               ;;
             --list      ) OPT_LIST=true                  ;;
             --all       ) OPT_ALL=true                   ;;
             *           ) sayred "invalid option: $OPTION"; exit 1 ;;
         esac
       OPTIND=1
       shift
      ;;
    *  ) sayred "invalid option: -$OPTARG"; exit 1 ;;
  esac
done

#TAPS="caskroom/cask homebrew/core homebrew/php homebrew/services"
#PACKAGES="git php71 php71-mcrypt jq ncdu node bash autojump"
#CASKS=""

if ( $OPT_UPDATE || $OPT_ALL ) ; then
  ### install homebrew if not installed
  if ! type -P brew > /dev/null ; then
      saygreen "installing homebrew ..."
      $DEBUG ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
  saygreen "updating homebrew ..."
  $DEBUG brew doctor
  $DEBUG brew prune
  $DEBUG brew update
  $DEBUG brew outdated
  $DEBUG brew upgrade
fi

saygreen "fetching current data ..."
brew tap > /dev/null
CURRTAPS=$(brew tap | xargs echo )
CURRPACKAGES=$(brew list -1 | xargs echo )
CURRCASKS=$(brew cask list -1 | xargs echo )

if ! type -P brew > /dev/null ; then
    echo "please install brew using --update option"
fi

if [ $OPT_SAVE ] ; then
  saygreen "saving $CONFIG ..."
  cat > $CONFIG <<EOF
TAPS="$CURRTAPS"
PACKAGES="$CURRPACKAGES"
CASKS="$CURRCASKS"
EOF
  exit
fi

saygreen "loading $CONFIG ..."
if ! [ -e $CONFIG ] ; then
    sayred "file $CONFIG not found"
    exit 1
fi
source $CONFIG
if [ -z $TAPS ] ; then
  sayred "wrong config file "
  exit 1
fi

#echo CURRTAPS="$CURRTAPS"
#echo CURRPACKAGES="$CURRPACKAGES"
#echo CURRCASKS="$CURRCASKS"
#echo TAPS="$TAPS"
#echo PACKAGES="$PACKAGES"
#echo CASKS="$CASKS"

if ( $OPT_REMOVE || $OPT_ALL ) ; then
  saygreen "removing ..."
  for x in $CURRTAPS; do
      if ! [[ $TAPS =~ $x ]]; then
          echo "removing tap $x"
          $DEBUG brew untap $x
      fi
  done
  for x in $CURRPACKAGES; do
      if ! [[ $PACKAGES =~ $x ]]; then
          echo "removing package $x"
          $DEBUG brew uninstall $x
      fi
  done
  for x in $CURRCASKS; do
      if ! [[ $CASKS =~ $x ]]; then
          echo "removing cask $x"
          $DEBUG brew cask uninstall $x
      fi
  done
fi

if ( $OPT_INSTALL || $OPT_ALL ) ; then
  saygreen "installing ..."
  for x in $TAPS; do
      if ! [[ $CURRTAPS =~ $x ]]; then
          echo "installing tap $x"
          $DEBUG brew tap $x
      else
          echo "tap $x alreaay installed"
      fi
  done
  for x in $PACKAGES ; do
      if ! [[ $CURRPACKAGES =~ $x ]]; then
          saygreen "installing package $x ..."
          $DEBUG brew install $x
      else
          echo "package $x already installed"
      fi
  done

  for x in $CASKS; do
      if ! [[ $CURRCASKS =~ $x ]]; then
          echo "adding cask $x"
          $DEBUG brew cask install $x
      else
          echo "cask $x alreaay installed"
      fi
  done
fi

if ( $OPT_LIST || $OPT_ALL ) ; then
  saygreen "listing brews"
  saygreen "taps:"
  brew tap
  saygreen "packages:"
  brew list
  saygreen "casks:"
  brew cask list
fi

saygreen "a final cleanup!"
#brew -v list
$DEBUG brew cleanup -s

saygreen "finished!"
