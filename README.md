# EFS volume release
This is a bosh release that packages an [efsdriver](https://github.com/cloudfoundry-incubator/efsdriver) and an [efsbroker](https://github.com/cloudfoundry-incubator/efsbroker) for consumption by a volume_services_enabled Cloud Foundry deployment.

This broker/driver pair allows you to provision new AWS Elastic File Systems and bind those volumes to your applications for shared file access in an AWS environment.

# Deploying to AWS EC2

## Pre-requisites

1. Install Cloud Foundry with Diego, or start from an existing CF+Diego deployment on AWS.  If you are starting from scratch, the article [Deploying CF and Diego to AWS](https://github.com/cloudfoundry/diego-release/tree/develop/examples/aws) provides detailed instructions. 

1. If you don't already have it, install spiff according to its [README](https://github.com/cloudfoundry-incubator/spiff). spiff is a tool for generating BOSH manifests that is required in some of the scripts used below.

## Create and Upload this Release

1. Check out efs-volume-release (master branch) from git:

    ```
    cd ~/workspace
    git clone https://github.com/cloudfoundry-incubator/efs-volume-release.git
    cd ~/workspace/efs-volume-release
    git checkout master
    ./scripts/update
    ```

1. Bosh Create and Upload the release
    ```
    bosh -n create-release --force && bosh -n upload-release
    ```

## Enable Volume Services in CF and Redeploy

In your CF manifest, check the setting for `properties: cc: volume_services_enabled`.  If it is not already `true`, set it to `true` and redeploy CF.  (This will be quick, as it only requires BOSH to restart the cloud controller job with the new property.) 

## Colocate the efsdriver job on the Diego Cell
If you have a bosh director version < `259` you will need to use one of the OLD WAYS below. (check `bosh environment` to determine your version).  Otherwise we recommend the NEW WAY :thumbsup::thumbsup::thumbsup:
### OLD WAY #1 Using Scripts to generate the Diego Manifest 
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

1. Now regenerate your diego manifest using the `-d` option, as detailed in [Setup Volume Drivers for Diego](https://github.com/cloudfoundry/diego-release/blob/develop/examples/aws/OPTIONAL.md#setup-volume-drivers-for-diego)

1. Redeploy Diego.  Again, this will be a fast operation as it only needs to start the new efsdriver job on each Diego cell.

### OLD WAY #2 Manual Editing
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
1. Add `efsdriver` to the `jobs: name: cell_z1 templates:` key
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
1. If you are using multiple AZz, repeeat step 2 for `cell_z2`, `cell_z3`, etc.

1. Redeploy Diego using your new manifest.

### NEW WAY Use bosh add-ons with filtering
This technique allows you to colocate bosh jobs on cells without editing the Diego bosh manifest.

1. Create a new `runtime-config.yml` with the following content:
   
```yaml
---
releases:
- name: efs-volume
  version: <YOUR VERSION HERE>
addons:
- name: voldrivers
  include:
    deployments: 
    - <YOUR DIEGO DEPLOYMENT NAME>
    jobs: 
    - name: rep
      release: diego
  jobs:
  - name: efsdriver
    release: efs-volume
    properties: {}
```

1. Set the runtime config, and redeploy diego

```bash
bosh update-runtime-config runtime-config.yml
bosh -d <YOUR DIEGO DEPLOYMENT NAME> manifest > diego.yml
bosh -d <YOUR DIEGO DEPLOYMENT NAME> deploy diego.yml
```

## Deploying efsbroker

### Create Stub Files

#### director.yml 
* determine your bosh director uuid by invoking `bosh environment`
* create a new director.yml file and place the following contents into it:
    ```
    ---
    director_uuid: <your uuid>
    ```

#### creds.yml
* Determine the following information
    - BROKER_USERNAME: some invented username 
    - BROKER_PASSWORD: some invented password
    - AWS_ACCESS_KEY_ID (optional): the access key id efsbroker will use to create new Elastic File Systems. If you do not already have an id/key pair, you can generate one from the AWS Console [Security Credentials page](https://console.aws.amazon.com/iam/home#security_credential). For an example IAM policy, see `policy.json`.
    - AWS_SECRET_ACCESS_KEY (optional): see above
    - AWS_SUBNET_IDS: the subnets you want to create new EFS volume mount points in, comma delimited.  For simple deployments, the subnet used by Diego cells will work.
    - AWS_SECURITY_GROUPS: the security groups you want to use for new mount points, one per subnet.  Again, for simple deployments you can reference the security group used by diego cells.
    - AWS_AZS: the availability zones of your subnets (one per subnet, comma delimited)

    Note: instead of setting `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, you can grant the relevant permissions to the broker instance using [IAM instance profiles](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html). This approach allows you to manage AWS permissions without creating and rotating IAM credentials. To use this approach, create an instance profile with the necessary permissions, create a [VM extension using BOSH cloud config](https://bosh.io/docs/cloud-config.html#vm-extensions) that names the instance profile, and associate the VM extension with the broker instance group, as follows:

    ```yaml
    vm_extensions:
    - name: efsbroker
      cloud_properties:
        iam_instance_profile: efsbroker
    ```

    ```yaml
    instance_groups:
    - name: efsbroker
      vm_extensions: [efsbroker]
    ```
    
* create a new creds.yml file and place the following contents into it:
    ```
    ---
    properties:
      efsbroker:
        username: <BROKER_USERNAME>
        password: <BROKER_PASSWORD>
        aws-access-key-id: <AWS_ACCESS_KEY_ID>
        aws-secret-access-key: <AWS_SECRET_ACCESS_KEY>
        aws-subnet-ids: <AWS_SUBNET_IDS>
        aws-security-groups: <AWS_SECURITY_GROUPS>
        aws-azs: <AWS_AZS>
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

* copy your cf.yml that you used during cf deployment, or download it from bosh: `bosh -d <YOUR CF DEPLOYMENT NAME> manifest > cf.yml`

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
    bosh -d <YOUR BROKER DEPLOYMENT NAME> deploy efs.yml
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
> ####Bind Parameters####
> * **mount:** By default, volumes are mounted into the application container in an arbitrarily named folder under /var/vcap/data.  If you prefer to mount your directory to some specific path where your application expects it, you can control the container mount path by specifying the `mount` option.  The resulting bind command would look something like 
> ``` cf bind-service pora myVolume -c '{"mount":"/var/my/path"}'```

## test the app to make sure that it can access your EFS volume
* to check if the app is running, `curl http://pora.YOUR.DOMAIN.com` should return the instance index for your app
* to check if the app can access the shared volume `curl http://pora.YOUR.DOMAIN.com/write` writes a file to the share and then reads it back out again.

## Troubleshooting
If you have trouble getting this release to operate properly, try consulting the [Volume Services Troubleshooting Page](https://github.com/cloudfoundry-incubator/volman/blob/master/TROUBLESHOOTING.md)
