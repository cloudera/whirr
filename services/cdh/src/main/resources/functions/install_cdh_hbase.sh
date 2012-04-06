#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
function register_cloudera_repo() {
  if which dpkg &> /dev/null; then
    cat > /etc/apt/sources.list.d/cloudera.list <<EOF
deb http://$REPO_HOST/debian lucid-$REPO contrib
deb-src http://$REPO_HOST/debian lucid-$REPO contrib
EOF
    curl -s http://$REPO_HOST/debian/archive.key | apt-key add -
    retry_apt_get update
  elif which rpm &> /dev/null; then
    rm -f /etc/yum.repos.d/cloudera.repo
    REPO_NUMBER=`echo $REPO | sed -e 's/cdh\([0-9][0-9]*\)/\1/'`
    cat > /etc/yum.repos.d/cloudera-$REPO.repo <<EOF
[cloudera-$REPO]
name=Cloudera's Distribution for Hadoop, Version $REPO_NUMBER
mirrorlist=http://$REPO_HOST/redhat/cdh/$REPO_NUMBER/mirrors
gpgkey = http://$REPO_HOST/redhat/cdh/RPM-GPG-KEY-cloudera
gpgcheck = 0
EOF
    retry_yum update -y yum
  fi
}

function install_cdh_hbase() {
  local OPTIND
  local OPTARG
  
  HBASE_TAR_URL=
  while getopts "u:" OPTION; do
    case $OPTION in
    u)
      # ignore tarball
      ;;
    esac
  done
  
  case $CLOUD_PROVIDER in
    ec2 | aws-ec2 )
      # Alias /mnt as /data
      if [ ! -e /data ]; then ln -s /mnt /data; fi
      ;;
    *)
      ;;
  esac
  
  REPO=${REPO:-cdh3}
  REPO_HOST=${REPO_HOST:-archive.cloudera.com}
  HBASE_HOME=/usr/lib/hbase
  
  # up file-max
  sysctl -w fs.file-max=65535
  # up ulimits
  echo "root soft nofile 65535" >> /etc/security/limits.conf
  echo "root hard nofile 65535" >> /etc/security/limits.conf
  ulimit -n 65535
  # up epoll limits; ok if this fails, only valid for kernels 2.6.27+
  set +e
  sysctl -w fs.epoll.max_user_instances=4096 > /dev/null 2>&1
  set -e
  # if there is no hosts file then provide a minimal one
  [ ! -f /etc/hosts ] && echo "127.0.0.1 localhost" > /etc/hosts

  register_cloudera_repo
  
  if which dpkg &> /dev/null; then
    retry_apt_get update
    retry_apt_get -y install hadoop-hbase
  elif which rpm &> /dev/null; then
    retry_yum install -y hadoop-hbase
  fi
  
  echo "export HBASE_HOME=$HBASE_HOME" >> ~root/.bashrc
  echo 'export PATH=$JAVA_HOME/bin:$HBASE_HOME/bin:$PATH' >> ~root/.bashrc
}
