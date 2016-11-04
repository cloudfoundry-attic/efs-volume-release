# EFS volume release
This is a bosh release that packages an [efsdriver](https://github.com/cloudfoundry-incubator/efsdriver) and an [efsbroker](https://github.com/cloudfoundry-incubator/efsbroker) for consumption by a volume_services_enabled Cloud Foundry deployment.

This broker/driver pair allows you to provision new AWS Elastic File Systems and bind those volumes to your applications for shared file access in an AWS environment.

# Deploying to AWS EC2

## Pre-requisites

1. Install Cloud Foundry with Diego, or start from an existing CF+Diego deployment on AWS.  If you are starting from scratch, the article [Deploying CF and Diego to AWS](https://github.com/cloudfoundry/diego-release/tree/develop/examples/aws) provides detailed instructions. 

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
    - BROKER_USERNAME: some invented username 
    - BROKER_PASSWORD: some invented password
    - AWS_ACCESS_KEY_ID: the access key id efsbroker will use to create new Elastic File Systems. If you do not already have an id/key pair, you can generate one from the AWS Console [Security Credentials page](https://console.aws.amazon.com/iam/home#security_credential) 
    - AWS_SECRET_ACCESS_KEY: see above
    - AWS_SUBNET_ID: the subnet you want to create new EFS volume mount points in.  For simple deployments, the subnet used by Diego cells will work.
    - AWS_SECURITY_GROUP: the security group you want to use for new mount points.  Again, for simple deployments you can reference the security group used by diego cells.
    
* create a new creds.yml file and place the following contents into it:
    ```
    ---
    properties:
      efsbroker:
        username: <BROKER_USERNAME>
        password: <BROKER_PASSWORD>
        aws-access-key-id: <AWS_ACCESS_KEY_ID>
        aws-secret-access-key: <AWS_SECRET_ACCESS_KEY>
        aws-subnet-ids: <AWS_SUBNET_ID>
        aws-security-group: <AWS_SECURITY_GROUP>
    ```
    
#### iaas.yml

* Create a stub for your iaas settings using the following template:-
    ```
    ---
    jobs:
    - name: efsbroker
      networks:
      - name: public
        static_ips: [52.87.35.4]
    
    networks:
    - name: efsvolume-subnet
      subnets:
      - cloud_properties:
          security_groups:
          - <--- SECURITY GROUP YOU WANT YOUR EFSBROKER TO BE IN --->
          subnet: <--- SUBNET YOU WANT YOUR EFSBROKER TO BE IN --->
        dns:
        - 10.10.0.2
        gateway: 10.10.200.1
        range: 10.10.200.0/24
        reserved:
        - 10.10.200.2 - 10.10.200.9
        - 10.10.200.106 - 10.10.200.115
        static:
        - 10.10.200.10 - 10.10.200.105
    
    resource_pools:
      - name: medium
        stemcell:
          name: bosh-aws-xen-hvm-ubuntu-trusty-go_agent
          version: latest
        cloud_properties:
          instance_type: m3.medium
          availability_zone: us-east-1c
      - name: large
        stemcell:
          name: bosh-aws-xen-hvm-ubuntu-trusty-go_agent
          version: latest
        cloud_properties:
          instance_type: m3.large
          availability_zone: us-east-1c
    ```

#### cf.yml

* copy your cf.yml that you used during cf deployment, or download it from bosh: `bosh download manifest [your cf deployment name] > cf.yml`

### Generate the Deployment Manifest
* manually edit templates/efsvolume-manifest-aws.yml to fix hard coded subnets, ip ranges, security groups, and URIs to match your deployment.
* manually edit templates/toplevel-manifest-overrides.yml to fix the compilation VM AZ if you are not running in the us-east data center.
* run the following spiff merge:
    ```
    spiff merge templates/efsvolume-manifest-aws.yml cf.yml director-uuid.yml creds.yml iaas.yml templates/toplevel-manifest-overrides.yml > efs.yml
    ```

### Deploy EFS Broker
* type the following: 
    ```
    bosh -d efs.yml deploy
    ```
    
## Register efs-broker
* type the following: 
    ```
    cf create-service-broker efsbroker <BROKER_USERNAME> <BROKER_PASSWORD> http://efsbroker.YOUR.DOMAIN.com
    cf enable-service-access efs
    ```

## Create an EFS volume service
* type the following: 
    ```
    cf create-service efs generalPurpose myVolume
    cf services
    ```
* keep invoking `cf services` until the myVolume service shows as ready

## Deploy the pora test app, bind it to your service and start the app
* type the following: 
    ```bash
    cd src/code.cloudfoundry.org/persi-acceptance-tests/assets/pora
    
    cf push pora --no-start
    
    cf bind-service pora myVolume
    
    cf start pora
    ```

## test the app to make sure that it can access your EFS volume
* to check if the app is running, `curl http://pora.YOUR.DOMAIN.com` should return the instance index for your app
* to check if the app can access the shared volume `curl http://pora.YOUR.DOMAIN.com/write` writes a file to the share and then reads it back out again.