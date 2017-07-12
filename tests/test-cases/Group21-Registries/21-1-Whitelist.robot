# Copyright 2017 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

*** Settings ***
Documentation  Test 21-01 - Whitelist
Resource  ../../resources/Util.robot
Resource  ../../resources/Harbor-Util.robot
Suite Setup  Setup Registries
Suite Teardown  Cleanup Registries
Test Teardown  Cleanup VIC Appliance On Test Server

*** Keywords ***
Setup Registries
    Install VIC Appliance To Test Server
    Remove Environment Variable  DOCKER_HOST
    Set Environment Variable  INSECURE-URL  %{VCH-IP}:5000
    Set Environment Variable  INSECURE-NAME  %{VCH-NAME}
    Set Environment Variable  INSECURE-ADMIN  %{VIC-ADMIN}
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} run -d -p 5000:5000 --restart=always --name insecure-registry registry:2
    Should Be Equal As Integers  ${rc}  0

    Install VIC Appliance To Test Server  cleanup=${false}
    Remove Environment Variable  DOCKER_HOST
    Set Environment Variable  SECURE-URL  %{VCH-IP}:8000
    Set Environment Variable  SECURE-NAME  %{VCH-NAME}
    Set Environment Variable  SECURE-ADMIN  %{VIC-ADMIN}
    Create Self Signed Certs
    ${rc}  ${output}=  Run And Return Rc And Output  docker run -d -p 8000:80 --restart=always --name secure-registry -e REGISTRY_HTTP_ADDR=0.0.0.0:80 -v certs:/certs -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/ca.crt -e REGISTRY_HTTP_TLS_KEY=/certs/ca.key registry:2
    Should Be Equal As Integers  ${rc}  0

    Remove Environment Variable  VCH-NAME
    Remove Environment Variable  VIC-ADMIN

Cleanup Registries
    Set Environment Variable  VCH-NAME  %{INSECURE-NAME}
    Set Environment Variable  VIC-ADMIN  %{INSECURE-ADMIN}
    Cleanup VIC Appliance On Test Server
    Set Environment Variable  VCH-NAME  %{SECURE-NAME}
    Set Environment Variable  VIC-ADMIN  %{SECURE-ADMIN}
    Cleanup VIC Appliance On Test Server

*** Test Cases ***
Insecure Registry Whitelist
    # Install VCH with insecure registry for whitelisted registry
    ${output}=  Install VIC Appliance To Test Server  cleanup=${false}  additional-args=--whitelist-registry=%{INSECURE-URL} --insecure-registry=%{INSECURE-URL}
    Should Contain  ${output}  Whitelist registries =

    # Check docker info for whitelist info
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} info
    Should Be Equal As Integers  ${rc}  0
    Should Contain  ${output}  Registry Whitelist Mode: enabled
    Should Contain  ${output}  Whitelisted Registries:
    Should Contain  ${output}  Registry: registry-1.docker.io
    
    # Try to login and pull from the whitelisted insecure registry with (should succeed)
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} login -u admin -p anyPassword %{INSECURE-URL}
    Should Contain  ${output}  Succeeded
    Should Be Equal As Integers  ${rc}  0
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} pull busybox
    Should Be Equal As Integers  ${rc}  0
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} tag busybox %{INSECURE-URL}/busybox:insecure
    Should Be Equal As Integers  ${rc}  0
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} push %{INSECURE-URL}/busybox:insecure
    Should Be Equal As Integers  ${rc}  0
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} pull %{INSECURE-URL}/busybox:insecure
    Should Be Equal As Integers  ${rc}  0

    # Try to login and pull from docker hub (should fail)
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} login --username=victest --password=vmware!123
    Should Be Equal As Integers  ${rc}  1
    Should Contain  ${output}  Access denied to unauthorized registry
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} pull victest/busybox
    Should Be Equal As Integers  ${rc}  1
    Should Contain  ${output}  Access denied to unauthorized registry

Secure Registry Whitelist
    # Install VCH with registry CA for whitelisted registry
    ${output}=  Install VIC Appliance To Test Server  cleanup=${false}  additional-args=--whitelist-registry=%{SECURE-URL} --registry-ca=certs/ca.crt
    Should Contain  ${output}  Secure registry %{SECURE-URL} confirmed
    Should Contain  ${output}  Whitelist registries =

    # Check docker info for whitelist info
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} info
    Should Be Equal As Integers  ${rc}  0
    Should Contain  ${output}  Registry Whitelist Mode: enabled
    Should Contain  ${output}  Whitelisted Registries:
    Should Contain  ${output}  Registry: registry-1.docker.io

    # Try to login and pull from the secure whitelisted registry (should succeed)
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} login -u admin -p anyPassword %{SECURE-URL}
    Should Contain  ${output}  Succeeded
    Should Be Equal As Integers  ${rc}  0
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} pull busybox
    Should Be Equal As Integers  ${rc}  0
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} tag busybox %{SECURE-URL}/busybox:secure
    Should Be Equal As Integers  ${rc}  0
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} push %{SECURE-URL}/busybox:secure
    Should Be Equal As Integers  ${rc}  0
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} pull %{SECURE-URL}/busybox:secure
    Should Be Equal As Integers  ${rc}  0

    # Try to login and pull from docker hub (should fail)
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} login --username=victest --password=vmware!123
    Should Be Equal As Integers  ${rc}  1
    Should Contain  ${output}  Access denied to unauthorized registry
    ${rc}  ${output}=  Run And Return Rc And Output  docker %{VCH-PARAMS} pull victest/busybox
    Should Be Equal As Integers  ${rc}  1
    Should Contain  ${output}  Access denied to unauthorized registry
