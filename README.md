# EFS volume release
This is a bosh release that packages an [efsdriver](https://github.com/cloudfoundry-incubator/efsdriver) and an [efsbroker](https://github.com/cloudfoundry-incubator/efsbroker) for consumption by a volume_services_enabled Cloud Foundry deployment.

# Deploying to AWS EC2

## Pre-requisites

1. Install Cloud Foundry with Diego, or start from an existing CF+Diego deployment on AWS.  If you are starting from scratch, the article [Deploying CF and Diego to AWS](https://github.com/cloudfoundry/diego-release/tree/develop/examples/aws) provides detailed instructions 

2. If you don't already have it, install spiff according to its [README](https://github.com/cloudfoundry-incubator/spiff). spiff is a tool for generating BOSH manifests that is required in some of the scripts used below.

## Create and Upload this Release

1. Check out efs-volume-release (master branch) from git:

    ```
    cd ~/workspace
    git clone https://github.com/cloudfoundry-incubator/efs-volume-release.git
    cd ~/workspace/efs-volume-release
    git checkout master
    ./scripts/update
    ```

2. Bosh Create and Upload the release
    ```
    bosh -n create release --force && bosh -n upload release
    ```

## Enable Volume Services in CF and Redeploy

In your CF manifest, check the setting for `properties: cc: volume_services_enabled`.  If it is not already `true`, set it to `true` and redeploy CF.  (This will be quick, as it only requires BOSH to restart the cloud controller job with the new property.) 

## Modify the Diego Manifest to Include the efsdriver job on the Diego Cell

### Using Scripts
If you originally created your Diego manifest from the scripts in diego-release, then you can use the same scripts to recreate the manifest with efs driver included. 

1. In your diego-release folder, locate the file `manifest-generation/bosh-lite-stubs/experimental/voldriver/drivers.yml` and copy it into your local directory.  Edit it to look like this:

    ```
    volman_overrides:
      releases:
      - name: efs-volume
        version: "latest"
      driver_templates:
      - name: efsdriver
        release: efs-volume
    ```

2. Now regenerate your diego manifest using the `-d` option, as detailed in [Setup Volume Drivers for Diego](https://github.com/cloudfoundry/diego-release/blob/develop/examples/aws/OPTIONAL.md#setup-volume-drivers-for-diego)

3. Redeploy Diego.  Again, this will be a fast operation as it only needs to start the new efsdriver job on each Diego cell.

### Manual Editing
If you did not use diego scripts to generate your manifest, you can manually edit your diego manifest to include the driver. 

1. Add `efs-volume` to the `releases:` key
    ```
    releases:
    - name: diego
      version: latest
      ...
    - name: efs-volume
      version: latest
    ```
2. Add `efsdriver` to the `jobs: name: cell_z1 templates:` key
    ```
    jobs:
      ... 
      - name: cell_z1
        ... 
        templates:
        - name: consul_agent
          release: cf
          ... 
        - name: efsdriver
          release: efs-volume
    ```
3. If you are using multiple AZz, repeeat step 2 for `cell_z2`, `cell_z3`, etc.

4. Redeploy Diego using your new manifest.

## Deploying efsbroker

### Create Stub Files

#### director.yml 
* determine your bosh director uuid by invoking bosh status --uuid
* create a new director.yml file and place the following contents into it:
    ```
    ---
    director_uuid: <your uuid>
    ```

#### creds.yml
* Determine the following information
    - BOSH_USERNAME: the admin user name you use with `bosh login`
    - BOSH_PASSWORD: the password you use with `bosh login`
    - AWS_ACCESS_KEY_ID: the access key id efsbroker will use to create new Elastic File Systems. If you do not already have an id/key pair, you can generate one from the AWS Console [Security Credentials page](https://console.aws.amazon.com/iam/home#security_credential) 
    - AWS_SECRET_ACCESS_KEY: see above
    - AWS_SUBNET_ID: the subnet you want to create new EFS volume mount points in.  For simple deployments, the subnet used by Diego cells will work.
    - AWS_SECURITY_GROUP: the security group you want to use for new mount points.  Again, for simple deployments you can reference the security group used by diego cells.
    
* create a new creds.yml file and place the following contents into it:
    ```
    ---
    properties:
      efsbroker:
        username: <BOSH_USERNAME>
        password: <BOSH_PASSWORD>
        aws-access-key-id: <AWS_ACCESS_KEY_ID>
        aws-secret-access-key: <AWS_SECRET_ACCESS_KEY>
        aws-subnet-ids: <AWS_SUBNET_ID>
        aws-security-group: <AWS_SECURITY_GROUP>
    ```
    
#### cf.yml














VVVVV GARBAGE VVVVV

8. Execute the following script to generate all manifests and deploy:-

    ```bash
    cd ~/workspace/local-volume-release
    ./scripts/deploy-bosh-lite.sh
    ```

## Register local-broker

    ```
    # optionaly delete previous broker:
    cf delete-service-broker localbroker
    
    cf create-service-broker localbroker admin admin http://localbroker.bosh-lite.com
    cf enable-service-access local-volume
    ```

## Deploy pora and test volume services

    ```bash
    cf create-service local-volume free-local-disk local-volume-instance
    
    cf push pora -f ./assets/pora/manifest.yml -p ./assets/pora/ --no-start
    
    cf bind-service pora local-volume-instance
    
    cf start pora
    ```

