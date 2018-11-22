#!/usr/bin/env bash
#/
#/ Update the UserData in the CloudFormation template with the installation script
#/ Please note, this script needs `jq` utility (https://stedolan.github.io/jq/) to work
#/
#/ Usage: update-cf-template.sh CloudFront.template installation-script.sh
#/

set -eu

#
# Display usage of the script, which is a specially marked comment
#
usage() {
  grep '^#/' <"$0" | cut -c 4-
}

#
# Convert a file to a JSON array of strings
#
# Example: file-to-json ./some-file
#
file-to-json() {
    local file_to_convert="$1"
    # split the text by the newline char and add that newline char back to each line
    jq -n '$text / "\n" | .[] |= . + "\n"' --arg text "$(cat "${file_to_convert}")"
}

#
# The UserData template
# This is a JSON snippet, which goes into the UserData field of the EC2 instance in the CloudFormation template
#
format-file-content() {
    local script="$1"
    local json=$(cat - << 'EOT'
{
  "Fn::Join": [
    "",
    $SCRIPT
  ]
}
EOT
)
    jq -n "${json}" --argjson SCRIPT "${script}"
}

# Check for the command arguments, it should be exactly two of them
if [ $# -ne 2 ]
then
    usage
    exit 75
fi


# Process the command arguments
CF_TEMPLATE="$1"; shift
INSTALL_SCRIPT_FILE="$1"; shift

# Load the installation script to a JSON string array
INSTALL_SCRIPT_JSON=$(file-to-json "${INSTALL_SCRIPT_FILE}")

# Add the installation script to the JSON template of the UserData field
INSTALL_FILE_CONTENT=$(format-file-content "${INSTALL_SCRIPT_JSON}")

# Update the UserData field in the CloudFormation template
jq '.Resources.EC2Instance.Metadata["AWS::CloudFormation::Init"].Install.files["/usr/local/bin/corda-install.sh"].content = $CONTENT' --argjson CONTENT "${INSTALL_FILE_CONTENT}" "${CF_TEMPLATE}"
