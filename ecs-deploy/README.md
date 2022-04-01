# ECS FARFATE DEPLOY

This simple script starts a new blue/green deploy on AWS ECS fargate updating the last task definition with the new docker image tag provided.

Usage:



## How to install and use

```sh
git clone ...
```

```sh
echo "\n#DNS EYE SCRIPT\nalias ecs_deploy="$PWD/ecs_deploy.sh"" >> ~/.bashrc && . ~/.bashrc
# (export your aws cli credentials before executing the script)
ecs_deploy {env} {docker_image}
```

