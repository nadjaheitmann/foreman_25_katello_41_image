#!/bin/bash

cd /projects
git clone --depth 1 https://github.com/atix-ag/foreman_scc_manager.git
echo "gemspec :path => '../foreman_scc_manager', :development_group => 'foreman_scc_manager_dev', :name => 'foreman_scc_manager'" > bundler.d/foreman_rh_cloud.local.rb

