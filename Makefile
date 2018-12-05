# Automate manipulation of the CloudFormation template and testing of the stack a little bit
CF_TEMPLATE=os.json
CF_UPDATED=os-updated.template
# a silly way to allow two different names to provide Testnet key
OTK=$(ONE_TIME_DOWNLOAD_KEY)
ONE_TIME_DOWNLOAD_KEY=
# the SSh key name configured in the AWS EC2
SSH_KEY=
# input required during initial Corda node installation
COUNTRY=GB
LOCALITY="London"
STACK=corda
# macros
IP=$$(aws cloudformation describe-stacks --stack-name $(STACK) --query 'Stacks[].Outputs[?OutputKey==`InstanceIPAddress`].OutputValue' --output text)
EC2ID=$$(aws cloudformation describe-stacks --stack-name $(STACK) --query 'Stacks[].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text)
AMIID=$$(grep -E 'message, +amazon-ebs: AMI:'  packer-build.log | sed -e 's/.*\(ami-*\)/\1/')
# constants
AWS_REGION=us-east-1

.PHONY: all test clean ssh userdata test-install-script ami

all: clean create-stack ami

create-stack: os-updated.template
	@echo "Creating CF stack for Corda Node installation"
	@aws --region=$(AWS_REGION) cloudformation create-stack \
         --stack-name $(STACK) \
         --template-body file://$$(pwd)/$(CF_UPDATED) \
         --parameters \
         	ParameterKey=KeyName,ParameterValue=$(SSH_KEY) \
         	ParameterKey=TestnetKey,ParameterValue=$(OTK) \
         	ParameterKey=Locality,ParameterValue=$(LOCALITY) \
         	ParameterKey=Country,ParameterValue=$(COUNTRY)
	@echo -n "The EC2 instance ID in the region $(AWS_REGION) is: " $(EC2ID)

delete-stack:
	@echo "Deleting CF stack for Corda Node installation"
	@aws --region=$(AWS_REGION) cloudformation delete-stack \
         --stack-name $(STACK)

userdata:
	@aws --region=$(AWS_REGION) ec2 describe-instance-attribute --attribute userData --instance-id $(EC2ID) --query 'UserData.Value' --output text | base64 -d -
ssh:
	@ssh ec2-user@$(IP)

$(CF_UPDATED): $(CF_TEMPLATE) packer-build.log
	@echo "Updating the CF template with the AMI ID"
	@jq '.Mappings.AWSRegionArch2AMI[$$AWS_REGION].HVM64 = $$AMI' --arg AMI $(AMIID) $(CF_TEMPLATE) --arg AWS_REGION $(AWS_REGION) >$(CF_UPDATED)

clean:
	@echo "Removing temporary files"
	@rm -f $(CF_UPDATED)

test-install-script:
	@echo "Testing the install.sh script"
	@cat install.sh | ssh -t ec2-user@$(IP) "sudo bash -c 'cat - > /usr/local/bin/corda-install.sh'; /usr/local/bin/corda-install.sh $(IP) 10000 $(OTK) $(COUNTRY) '$(LOCALITY)'"

test-zulu-install-script:
	@echo "Testing the install-zulu-jdk.sh script"
	@cat install-zulu-jdk.sh | ssh -t ec2-user@$(IP) "sudo bash -c 'cat - > /tmp/zulu.sh; chmod a+x /tmp/zulu.sh'; /tmp/zulu.sh -v"

ami: packer-build.log
	@echo "Getting the ID of created AMI from the Packer build log:" $(AMIID)

packer-build.log: packer-template.json install-zulu-jdk.sh install.sh
	@echo "Creating a new AMI with Packer"
	@packer build -machine-readable -var "aws_region=$(AWS_REGION)" packer-template.json 2>packer-build.err | tee packer-build.log
