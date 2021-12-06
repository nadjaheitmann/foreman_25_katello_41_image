FROM centos:7 AS base

ENV PGHOST=postgres
ENV PGUSER=postgres
ENV PGPASS=postgres
ENV RAILS_ENV=test
ENV GIT_COMMITTER_NAME="gh_actions"
ENV GIT_COMMITTER_EMAIL="gh_actions@.foreman_scc_manager.atix"
ENV WORKDIR=/projects/foreman
ENV BUNDLE_PATH=vendor/bundle

ARG SCLS="rh-ruby25 rh-nodejs12 sclo-git25 rh-postgresql12"

RUN \
  yum install -y centos-release-scl \
                 epel-release; \
  yum install -y systemd-devel \
                 make \
                 tar \
                 libvirt-devel \
                 rh-ruby25-ruby-devel \
                 zlib-devel \
                 libxml2-devel \
                 openssl-libs \
                 libvirt-devel \
                 nodejs \
                 rh-ruby25-rubygems \
                 automake \
                 gcc \
                 gcc-c++ \
                 kernel-devel \
                 libcurl-devel \
                 sqlite-devel \
                 rh-nodejs12-npm \
                 sclo-git25 \
                 rh-postgresql12-postgresql-devel \
                 rh-postgresql12-postgresql \
                 qpid-proton-cpp-devel; \
  source scl_source enable $SCLS; \
  git config --global user.name $GIT_COMMITTER_NAME; \
  git config --global user.email $GIT_COMMITTER_EMAIL; \
  mkdir /projects; \
  cd /projects; \
  git clone --depth 1 --branch 2.5-stable https://github.com/theforeman/foreman.git; \
  git clone --depth 1 --branch KATELLO-4.1 https://github.com/Katello/katello.git; \
  git clone --depth 1 --branch v4.1.5 https://github.com/theforeman/foreman-tasks.git;

RUN \
  cd /projects/foreman; \
  echo "gemspec :path => '../katello', :development_group => :dev" > bundler.d/katello.local.rb; \
  echo "gemspec :path => '../foreman-tasks', :development_group => :dev, :name => 'foreman-tasks'" > bundler.d/foreman-tasks.local.rb; \
  echo "gem 'foreman_remote_execution', '~> 4.5.6'" > bundler.d/foreman_remote_execution.local.rb; \
  echo "gem 'qpid_proton', '~> 0.33.0'" >> bundler.d/katello.local.rb;

WORKDIR /projects/foreman
RUN \
  source scl_source enable $SCLS; \
  gem install bundler:1.17.3; \
  bundle config path vendor/bundle; \
  npm install npm-proxy-cache -g; \
  npm config set proxy http://localhost:8080/; \
  npm config set https-proxy http://localhost:8080/; \
  npm config set strict-ssl false

FROM base AS foreman_setup

WORKDIR /projects/foreman
ARG SCLS="rh-ruby25 rh-nodejs12 sclo-git25 rh-postgresql12"
RUN \
  source scl_source enable $SCLS; \
  cd /projects/foreman; \
  bundle install --jobs=3 --retry=3 --without journald development console
RUN \
  source scl_source enable $SCLS; \
  cd /projects/foreman; \
  npm-proxy-cache & \
  bundle exec npm install

FROM foreman_setup AS plugins_setup

WORKDIR /projects/foreman
ARG SCLS="rh-ruby25 rh-nodejs12 sclo-git25 rh-postgresql12"
RUN \
  source scl_source enable $SCLS; \
  cd /projects/foreman; \
  npm-proxy-cache & \
  bundle exec ./script/npm_install_plugins.js

COPY ./entrypoint.sh /usr/bin/

RUN sed -i s/SCLS=/SCLS=\""$SCLS"\"/g /usr/bin/entrypoint.sh

RUN chmod +x /usr/bin/entrypoint.sh

COPY ./setup_project.sh /usr/bin/
RUN chmod +x /usr/bin/setup_project.sh

COPY ./run_tests.sh /usr/bin/
RUN chmod +x /usr/bin/run_tests.sh

CMD ["/usr/bin/run_tests.sh"]

ENTRYPOINT ["entrypoint.sh"]
