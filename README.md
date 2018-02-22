# EFS volume release
This is a bosh release that packages an [efsdriver](https://github.com/cloudfoundry-incubator/efsdriver) and an [efsbroker](https://github.com/cloudfoundry-incubator/efsbroker) for consumption by a volume_services_enabled Cloud Foundry deployment.

This broker/driver pair allows you to provision new AWS Elastic File Systems and bind those volumes to your applications for shared file access in an AWS environment.

# Deploying to AWS EC2

## Pre-requisites

1. Install Cloud Foundry, or start from an existing CF deployment.  If you are starting from scratch, the article [Overview of Deploying Cloud Foundry](https://docs.cloudfoundry.org/deploying/index.html) provides detailed instructions.
> **NB:** you must deploy Cloud Foundry to an AWS region that supports EFS.  See [this table](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) for region support.

1. Install [GO](https://golang.org/dl/):

    ```bash
    mkdir ~/workspace ~/go
    cd ~/workspace
    wget https://storage.googleapis.com/golang/go1.9.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.9.linux-amd64.tar.gz
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
    exec $SHELL
    ```

1. Install [direnv](https://github.com/direnv/direnv#from-source):

    ```bash
    mkdir -p $GOPATH/src/github.com/direnv
    git clone https://github.com/direnv/direnv.git $GOPATH/src/github.com/direnv/direnv
    pushd $GOPATH/src/github.com/direnv/direnv
        make
        sudo make install
    popd
    echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
    exec $SHELL
    ```

## Create and Upload this Release

1. Check out efs-volume-release (master branch) from git:

    ```
    cd ~/workspace
    git clone https://github.com/cloudfoundry-incubator/efs-volume-release.git
    cd ~/workspace/efs-volume-release
    direnv allow
    git checkout master
    ./scripts/update
    ```

1. Bosh Create and Upload the release
    ```
    bosh -n create-release --force && bosh -n upload-release
    ```
## Create a variables file with your AWS credentials

Create an `efs-vars.yml` file with the following format:

    ```
    ---
    aws-access-key-id: AWS_ACCESS_KEY_ID
    aws-secret-access-key: AWS_SECRET_ACCESS_KEY
    aws-subnet-ids: AWS_SUBNET_IDS 
    aws-security-groups: AWS_SECURITY_GROUPS
    aws-azs: AWS_AZ
    efs-broker-password: EFS_BROKER_PASSWORD
    ```

Values for the above variables should be set as follows:
- AWS_ACCESS_KEY_ID: AWS Access Key Id for the account managing EFS instances
- AWS_SECRET_ACCESS_KEY: AWS Secret Access Key for the account managing EFS instances
- AWS_SUBNET_IDS: Comma-separated AWS subnet Ids where mount targets should be created
- AWS_SECURITY_GROUPS: Comma separated AWS security group ids to assign to the mount points (one per subnet)
- AWS_AZ: Comma separated AWS AZs of the subnets (one per subnet)
- EFS_BROKER_PASSWORD: *OPTIONAL* password for the efs service broker.  If this value is omitted, BOSH will generate a password for you.

## Redeploy Cloud Foundry with EFS enabled

1. You should have it already after deploying Cloud Foundry, but if not clone the cf-deployment repository from git:

    ```bash
    $ cd ~/workspace
    $ git clone https://github.com/cloudfoundry/cf-deployment.git
    $ cd ~/workspace/cf-deployment
    ```

2. Now redeploy your cf-deployment while including the EFS ops file:
    ```bash
    $ bosh -e my-env -d cf deploy cf.yml \
    -v deployment-vars.yml \ 
    -v efs-vars.yml \
    -o ../efs-volume-release/operations/deploy-efs-broker-and-install-driver.yml
    ```
    
**Note:** the above command is an example, but your deployment command should match the one you used to deploy Cloud Foundry initially, with the addition of a `-o ../efs-volume-release/operations/deploy-efs-broker-and-install-driver.yml` option.

Your CF deployment will now have a running service broker and volume drivers, ready to create and mount efs volumes.  Unless you have explicitly defined a variable for your efsbroker password, BOSH will generate one for you.  
If you let BOSH generate the efsbroker password for you, you can find the password for use in broker registration via the bosh interpolate command:
    ```bash
    # BOSH CLI v2
    bosh int deployment-vars.yml --path /efs-broker-password
    ```

## Register efs-broker
* type the following:

    ```
    cf create-service-broker efsbroker admin <BROKER_PASSWORD> http://efs-broker.YOUR.DOMAIN.com
    cf enable-service-access efs
    ```

## Create an EFS volume service
* type the following:

    ```
    cf create-service efs generalPurpose myVolume
    cf services
    ```
* EFS volume creation is asynchronous.  Keep invoking `cf services` until the myVolume service shows as ready

## Deploy the pora test app, bind it to your service and start the app
* type the following:

    ```bash
    cd src/code.cloudfoundry.org/persi-acceptance-tests/assets/pora
    cf push pora --no-start
    cf bind-service pora myVolume
    cf start pora
    ```
> ####Bind Parameters####
> * **mount:** By default, volumes are mounted into the application container in an arbitrarily named folder under /var/vcap/data.  If you prefer to mount your directory to some specific path where your application expects it, you can control the container mount path by specifying the `mount` option.  The resulting bind command would look something like 
> `cf bind-service pora myVolume -c '{"mount":"/var/my/path"}'`

## test the app to make sure that it can access your EFS volume
* to check if the app is running, `curl http://pora.YOUR.DOMAIN.com` should return the instance index for your app
* to check if the app can access the shared volume `curl http://pora.YOUR.DOMAIN.com/write` writes a file to the share and then reads it back out again.

## Troubleshooting
If you have trouble getting this release to operate properly, try consulting the [Volume Services Troubleshooting Page](https://github.com/cloudfoundry-incubator/volman/blob/master/TROUBLESHOOTING.md)
