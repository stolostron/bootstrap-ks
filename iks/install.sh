#!/bin/bash

curl -sL https://ibm.biz/idt-installer | bash

if [ $? -ne 0 ]; then
    echo "IBM Cloud CLI installation failed, exiting with a failure"
    exit 1;
else
    echo "IBM Cloud CLI version $(ibmcloud version) installed successfullly."
fi
