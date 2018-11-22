Single Node CloudFormation Template
===================================

This CloudFormation template automates the installation of a single node running Corda Open Source with H2 database connecting to test net.

| Variable       | Description                                                                                                                                                                                                | Default     |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| `InstanceType` | The type of the instance as per [AWS documentation](https://aws.amazon.com/ec2/instance-types/), excluding nano/micro/small instances.                                                                     | `t2.medium` |
| `KeyName`      | Name of an existing EC2 KeyPair to enable SSH access to the instances. Needs to be configured [according to documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) in EC2. | --          |
| `SSHLocation`  | The IP address range that can be used to SSH to the EC2 instances                                                                                                                                          | `0.0.0.0/0` |
| `TestnetKey`   | The key to obtain the Corda installation from [Testnet](https://testnet.corda.network/).                                                                                                                   | --          |
| `P2PPort`      | The P2P Port this Corda instance should expose                                                                                                                                                             | `10000`     |
| `Country`      | The country the business entity operating the node is domiciled in                                                                                                                                         | --          |
| `Locality`     | The locality the business entity operating the node is domiciled in                                                                                                                                        | --          |                                                                                                                                                       | `10000`     |

A stack can be created locally using the [AWS CLI](https://aws.amazon.com/cli/):

```bash
aws cloudformation create-stack \
    --stack-name corda \
    --template-body file:///Users/moritzplatt/Projects/os-cloudformation/os.json \
    --parameters \
        ParameterKey=KeyName,ParameterValue=mykey \
        ParameterKey=InstanceType,ParameterValue=t2.large \
        ParameterKey=P2PPort,ParameterValue=10007 \
        ParameterKey=TestnetKey,ParameterValue=52412ec6-4db9-4958-b11c-ebc8dcf69d8a \
        ParameterKey=Country,ParameterValue=DE \
        ParameterKey=Locality,ParameterValue=Berlin
```

After creation, the stack can be inspected using the [CloudFormation UI](https://eu-west-2.console.aws.amazon.com/cloudformation/home).