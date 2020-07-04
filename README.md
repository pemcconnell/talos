talos
=====

build, test and run framework

The mission of this tool is to provide a widely compatable script which can
aide in the development and testing of software projects. The idea is to bundle
up common pre-production tooling into a docker image (which we call a toolbox)
so that all developers can quickly test against their code using the same
features used in CI.


install
-------

```sh
# read the contents of this file before running it
# you may want to skip this step after reading it and install manually
sh install.sh
```

commands
--------

```sh
talos
----------------------------------------------------------------------
help                 display all options
info                 display talos information for current working directory
lint                 run all available linters
test                 run all tests associated with this repo
docker               perform project-relevant docker commands
```

customise and extend
--------------------

One of the core principles of Talos is to allow the user to customise and
extend it's functionality. To do this, create a `.talos` folder *in your
project root* to place your desired customisations.

### custom configuration

One of the required customisations is a `config.sh` file placed into the
`.talos` directory of your project root. Here you can set project-specific
configurations for your project. For example:

`.talos/config.sh`
```sh
#!/usr/bin/env sh
# shellcheck disable=SC2034

set -e


hash() {
  if command -v md5 > /dev/null; then
    find "$1" -type f -and -not -path "./.git/*" -exec md5 -q {} \; | md5
  elif command -v md5sum > /dev/null; then
    find "$1" -type f -and -not -path "./.git/*" -exec md5sum {} \; | awk '{ print $1 }' | md5sum | awk '{ print $1 }'
  else
    >&2 echo "[error] failed to hash. no md5 or md5sum found"
    exit 1
  fi
}

TALOS_IMAGE=mycustomtoolbox:0.1
# DOCKER_COMPOSE_FILE=
DOCKER_TAG="myproject:$(hash "$PROJECT_ROOT")"
# DOCKER_FILE=
# DOCKER_CONTEXT=
# DOCKER_PROGRESS=
# HOME_DIR=
```

This file will be automatically picked up and when you run `talos docker build`
given the config.sh file above it will build your project as the image
"myproject" and a tag generated from an md5 hash of your files.

### custom functions

Adding custom functions to Talos is trivial. Place a shell file into your
projects `.talos/cmds/` directory with the filename to match the desired
command. In that file you should place a comment starting `# help: ` under the
shebang indicating the help text you wish to display. For examle, lets say
we wanted a "frog" function, we would add:

`./.talos/cmds/frog.sh`
```sh
#!/usr/bin/env sh
# help: ribbit im a frog

echo "ribbit! ...ribbit!"
```

Then when we run `talos` we can see our new command listed:

```sh
talos
----------------------------------------------------------------------
help                 display all options
info                 display talos information for current working directory
lint                 run all available linters
test                 run all tests associated with this repo
docker               perform project-relevant docker commands
frog                 ribbit im a frog
```

Now when we run `talos frog` we get to see our wonderful script in action:

```sh
talos frog
ribbit! ...ribbit!
```

### custom toolbox image

Want to use a handrolled docker image for running all of your linting / testing
etc in? Great. Set `TALOS_IMAGE=yourimage:0.1` in your `.talos/config.sh`. The
only requirement is that `talos` is installed in your image. The default image
is pemcconnell/talos:latest and it's found in ./toolboxes/Dockerfile.python in
this repo.

### overriding functions

Using the same approach that we took for custom functions, we can overwrite
core commands in the same way. For example, lets say that we want to change
`talos lint` so that it prints "lgtm" every time someone runs it, we create
a file in our project at `./.talos/cmds/lint.sh`:

```sh
#!/usr/bin/env sh
# help: linting made easy

echo "lgtm"
```

Now when you run `talos` you will see the core `lint` command has been replaced
by the custom one that we have created:

```sh
talos
----------------------------------------------------------------------
help                 display all options
info                 display talos information for current working directory
frog                 ribbit im a frog
lint                 linting made easy
test                 run all tests associated with this repo
docker               perform project-relevant docker commands
```

When we run `talos lint` we see our script has been executed:

```sh
talos lint
lgtm
```

core commands
-------------

### linting

Running `talos lint` will run the linter against your current working
directory. An example with some errors:

```sh
talos lint
 linting ...
 - checking for shell/bash
 [ info      ] checking ./install.sh
 [ info      ] checking ./cmds/lint.sh
 [ info      ] checking ./cmds/test.sh
 [ info      ] checking ./cmds/docker.sh
 [ info      ] checking ./talos.sh

In ./talos.sh line 63:
        if echo "$cmdcache" | egrep -q "@$name@"; then
                              ^---^ SC2196: egrep is non-standard and deprecated. Use grep -E instead.

For more information:
  https://www.shellcheck.net/wiki/SC2196 -- egrep is non-standard and depreca...
 [ info      ] checking ./.talos/config.sh
 - checking for docker
 [ info      ] checking ./Dockerfile
./Dockerfile:9 DL3008 Pin versions in apt get install. Instead of `apt-get install <package>` use `apt-get install <package>=<version>`
./Dockerfile:9 DL3009 Delete the apt-get lists after installing something
./Dockerfile:9 DL3015 Avoid additional packages by specifying `--no-install-recommends`
 - checking for python
 [ info      ] no python found. skipping
```

### docker build

To build with docker you can run `talos docker build`. This will attempt to autodetect if it is a docker-compose or Dockerfile build. If Dockerfile, it will attempt to detect if it is a buildkit image. An example (buildkit):

```sh
 ± talos docker build
#2 [internal] load .dockerignore
#2 transferring context: 2B done
#2 ...

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 3.10kB done
#1 DONE 0.7s
...
#18 exporting layers
#18 exporting layers 1.3s done
#18 writing image sha256:b7e247239e19114e71108899e598748300decb93f40020377a28b352ac8853aa done
#18 naming to docker.io/library/talos:40bd09002595f8ccda7d42c168ebdd0c done
#18 DONE 1.3s
```

### docker run

Once the image has been built you can run the container using `talos docker run`. This will automatically mount in a series of common volumes. For convenience this generated 'docker run' command is pasted prior to running the container so you can easily copy/paste it and tweak as required:

```sh
 talos docker run
 [ info      ] running docker run --rm  -e DISPLAY=unix/private/tmp/com.apple.launchd.WJTehPPKq2/org.macosforge.xquartz:0 -e HOST_HOME=/Users/someguy -ti talos:05b8266beeaaf11979f6ef888ad40db5
root@de84379554b6:/#
```

todo's
------

- [ ] pytest example with custom ini
- [ ] pytest reports
- [ ] test compose build and run
- [ ] create golang toolbox (./toolboxes/golang.Dockerfile)
- [ ] golang test example
- [ ] add golang linters
- [ ] add CI