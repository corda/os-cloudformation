# Automate manipulation of the CloudFormation template and testing of the stack a little bit
CF_TEMPLATE=os.json
CF_UPDATED=os-updated.template
OTK=
SSH_KEY=
COUNTRY=GB
LOCALITY="Milton Keynes"

.PHONY: all test clean ssh userdata test-install-script

all: clean test

test: os-updated.template
	@echo "Creating CF stack"
	@aws cloudformation create-stack \
         --stack-name ostest \
         --template-body file://$$(pwd)/$(CF_UPDATED) \
         --parameters \
         	ParameterKey=KeyName,ParameterValue=$(SSH_KEY) \
         	ParameterKey=TestnetKey,ParameterValue=$(OTK) \
         	ParameterKey=Locality,ParameterValue=$(LOCALITY) \
         	ParameterKey=Country,ParameterValue=$(COUNTRY)
	@echo -n "The EC2 instance ID is: "
	@aws cloudformation describe-stacks --stack-name ostest --query 'Stacks[].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text

userdata:
	@aws ec2 describe-instance-attribute --attribute userData --instance-id $$(aws cloudformation describe-stacks --stack-name ostest --query 'Stacks[].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text) --query 'UserData.Value' --output text | base64 -d -
ssh:
	@ssh ec2-user@$$(aws cloudformation describe-stacks --stack-name ostest --query 'Stacks[].Outputs[?OutputKey==`InstanceIPAddress`].OutputValue' --output text)

$(CF_UPDATED): $(CF_TEMPLATE) install.sh
	@echo "Updating the CF template with the install.sh"
	@./update-cf-template.sh $(CF_TEMPLATE) install.sh >$(CF_UPDATED)

clean:
	@echo "Removing temporary files"
	@rm -f $(CF_UPDATED)

test-install-script:
	cat install.sh | ssh -t ec2-user@$$(aws cloudformation describe-stacks --stack-name ostest --query 'Stacks[].Outputs[?OutputKey==`InstanceIPAddress`].OutputValue' --output text) "set -x; sudo bash -c 'cat - > /usr/local/bin/corda-install.sh'; /usr/local/bin/corda-install.sh 35.178.16.116 10000 $(OTK) $(COUNTRY) '$(LOCALITY)'"
