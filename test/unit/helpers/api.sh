#!/usr/bin/env bash
# Stub api.sh for unit tests — provides no-op implementations of API functions
# that list.sh uses at runtime (not at source time).

LoginAPI()      { :; }
LogoutAPI()     { :; }
PostFTLData()   { echo '{}'; }
GetFTLData()    { echo '{"domains":[]}'; }
