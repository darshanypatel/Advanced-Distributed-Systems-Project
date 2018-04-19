# CSC-724-Project

The following are the steps to follow to automatically create a Kubernetes cluster:

1. Install `ansible`, `pip` and `dopy`

```
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install -y ansible
sudo apt-get install -y python-pip
pip install dopy
```

Note: You need to have ansible version 2.5 or later to be able to run this code. Since there's a use of `k8s_raw` module of ansible which needs ansible version 2.5 or later. You can check ansible version using this command:

```
ansible --version
```

2. Clone this repo

```
git clone https://github.ncsu.edu/dpatel12/CSC-724-Project.git
```

3. Make a new file named "token" and put your DigitalOcean personal access token into it.

4. Copy Ansible config file into home directory

```
cp .ansible.cfg ~/.ansible.cfg
```

5. In the `kubernetes_setup.yml`, you may configure number of masters and workers to create in the `vars` section. All master nodes should contain 'master' word and all worker nodes should contain 'worker' word in it. By default, the script will create 1 master and 2 workers.

6. If you don't have a ssh key `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub` present in your machine, skip this step. Otherwise, if that same key is already there in your DigitalOcean account, then use that key name in - `roles/provision_droplets/tasks/main.yml` under task - `make sure the ssh key exists on digital_ocean` in the name attribute. If you have a key on your machine but not in the DigitalOcean account, then make sure you don't have a key called `kubernetes-checkbox` on your DigitalOcean account (if there is one then delete it or use it in `~/.ssh/id_rsa`).

7. Run the playbook using this command:
```
ansible-playbook kubernetes_setup.yml
```

8. If you want to clean up everything, use `delete_droplets.yml` to destroy all of your droplets (If you have changed the master/worker names in step 6, then write the same names in the `delete_droplets.yml` under droplets vars) Use this command to clean up:

```
ansible-playbook delete_droplets.yml
```
