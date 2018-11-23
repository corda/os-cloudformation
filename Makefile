# Automate manipulation of the CloudFormation template and testing of the stack a little bit
CF_TEMPLATE=os.json
CF_UPDATED=os-updated.template
OTK=
SSH_KEY=
COUNTRY=GB
LOCALITY="London"
STACK=corda
IP=$$(aws cloudformation describe-stacks --stack-name $(STACK) --query 'Stacks[].Outputs[?OutputKey==`InstanceIPAddress`].OutputValue' --output text)
EC2ID=$$(aws cloudformation describe-stacks --stack-name $(STACK) --query 'Stacks[].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text)

.PHONY: all test clean ssh userdata test-install-script

all: clean create-stack

create-stack: os-updated.template
	@echo "Creating CF stack for Corda Node installation"
	@aws cloudformation create-stack \
         --stack-name $(STACK) \
         --template-body file://$$(pwd)/$(CF_UPDATED) \
         --parameters \
         	ParameterKey=KeyName,ParameterValue=$(SSH_KEY) \
         	ParameterKey=TestnetKey,ParameterValue=$(OTK) \
         	ParameterKey=Locality,ParameterValue=$(LOCALITY) \
         	ParameterKey=Country,ParameterValue=$(COUNTRY)
	@echo -n "The EC2 instance ID is: " $(EC2ID)

delete-stack:
	@echo "Deleting CF stack for Corda Node installation"
	@aws cloudformation delete-stack \
         --stack-name $(STACK)

userdata:
	@aws ec2 describe-instance-attribute --attribute userData --instance-id $(EC2ID) --query 'UserData.Value' --output text | base64 -d -
ssh:
	@ssh ec2-user@$(IP)

$(CF_UPDATED): $(CF_TEMPLATE) install.sh
	@echo "Updating the CF template with the install.sh"
	@./update-cf-template.sh $(CF_TEMPLATE) install.sh >$(CF_UPDATED)

clean:
	@echo "Removing temporary files"
	@rm -f $(CF_UPDATED)

test-install-script:
	@echo "Testing the install.sh script"
	@cat install.sh | ssh -t ec2-user@$(IP) "sudo bash -c 'cat - > /usr/local/bin/corda-install.sh'; /usr/local/bin/corda-install.sh $(IP) 10000 $(OTK) $(COUNTRY) '$(LOCALITY)'"
