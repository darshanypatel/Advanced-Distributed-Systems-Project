# CSC-724-Project

## Authors:

Fogo Tunde-Onadele (oatundeo)

Darshan Patel (dpatel12)

## The following are the steps to automatically create a Kubernetes cluster:

1. Install `ansible`, `pip` and `dopy`

```
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install -y ansible
sudo apt-get install -y python-pip
pip install dopy
```

2. Clone this repo

```
git clone https://github.ncsu.edu/dpatel12/CSC-724-Project.git
```

3. Create an account on [digitalocean](https://www.digitalocean.com). Make a new file named "token" and put your DigitalOcean personal access token into it. You can generate a token from `API->Tokens/keys->Generate New Token`.

4. Copy Ansible config file into home directory

```
cp .ansible.cfg ~/.ansible.cfg
```

5. In the `kubernetes_setup.yml`, you may configure number of masters and workers to create in the `vars` section. All master nodes should contain 'master' word and all worker nodes should contain 'worker' word in it. By default, the script will create 1 master and 4 workers.

6. If you don't have a ssh key `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub` present in your machine, skip this step. Otherwise, if that same key is already there in your DigitalOcean account, then use that key name in - `roles/provision_droplets/tasks/main.yml` under task - `make sure the ssh key exists on digital_ocean` in the name attribute. If you have a key on your machine but not in the DigitalOcean account, then make sure you don't have a key called `kubernetes` on your DigitalOcean account (if there is one then delete it or use it in `~/.ssh/id_rsa`).

7. Run the playbook using this command:
```
ansible-playbook kubernetes_setup.yml
```

Note: this playbook creates a deployment and service for `apache` application by default. If you want to use any other application, use step 3 of the `patching process` below for creating a service for application of your choice.

8. If you want to clean up everything, use `delete_droplets.yml` to destroy all of your droplets (If you have changed the master/worker names in step 6, then write the same names in the `delete_droplets.yml` under droplets vars) Use this command to clean up:

```
ansible-playbook delete_droplets.yml
```

## After creating a kubernetes cluster:

Login to [digitalocean](https://www.digitalocean.com). You can see the master/worker droplets under resources. You can connect to any of the master/worker nodes using the IP address shown there. A simple `SSH` to root user will connect you to that machine. For example:

```
ssh root@174.138.56.240
```

1. Connect to the master node and using the below command, get the `nodeport` of `apache-service1` under `PORT(S)`. It is a number between 30000-32767.

```
kubectl get all
```

2. Make a file on `/etc/nginx/sites-enabled` called `nginx-reverse-proxy` and save it with this content:

```
server {

  listen 8080;
  location / {
    proxy_pass "https://174.138.56.240:31369/";
  }

}
```

Here `174.138.56.240` is the master node's IP address and `31369` is the nodeport of `apache-service1`. Replace that with what is it in your case.

3. Restart Nginx service:

```
systemctl restart nginx.service
```

Now you can access the service at `174.138.56.240:8080` in your browser.

## Installing collectd

1. Use the below command to get worker node on which the pods are running:

```
kubectl get pods -o wide
```

You can see the worker node under `NODE`.

2. Connect to the root user at IP address (get it from digitalocean) of this node where the service is running. You can now install and configure `collectd` on this worker node.

```
apt-get install collectd
apt-get install librrds-perl libjson-perl libhtml-parser-perl
cd /usr/local/
git clone https://github.com/httpdss/collectd-web.git
cd collectd-web/
chmod +x cgi-bin/graphdefs.cgi
vi runserver.py
```

Change `127.0.0.1 to 0.0.0.0` in this `runserver.py`

```
apt install libcgi-pm-perl
./runserver.py &
```

Update `/etc/collectd/collectd.conf` to make data in csv format. Open that file and uncomment the following lines and change StoreRates from false to true as shown below:

```
LoadPlugin csv

<Plugin csv>
        DataDir "/var/lib/collectd/csv"
        StoreRates true
</Plugin>
```

Restart the collectd service:

```
service collectd restart
```

You can check if the service is running using `systemctl status collectd.service`.
The data is store at `/var/lib/collectd/csv/`.
The `collectd-web` can be accessed at port 8888 on the worker node's IP where you have installed it. (Note: if you cannot see any hosts on this page, try running `apt install libcgi-pm-perl` again on the worker node where collectd is installed).

## Patching process:

1. Generate some load on the worker node where the service is running. We have used the following code for generating some traffic on the apache service:

```
import requests
while True:
    try:
        requests.get("http://174.138.56.240:8080/", verify=False)
    except requests.ConnectionError:
        print "Connection Error"
```

Here `174.138.56.240` is the master node's IP address. You can check the traffic is actually generated by using `docker stats <container ID>` command on the worker node.

2. Now wait for 10 minutes if you want to get resource usage of the container before patching it. Otherwise continue to next step.

3. Go back to master node and use the following commands to create a shadow deployment and service:

```
kubectl run apache-deployment2 --image=oatundeo/openssl-old:vulnerable --port=443 --replicas=1
kubectl expose deployment apache-deployment2 --type=NodePort --name=apache-service2
```

Here `apache-deployment2` is the deployment name, `oatundeo/openssl-old:vulnerable` is the `username/image-name:tag`, port is the port at which this service will run, `apache-service2` is the service name.

4. Now you can get the nodeport of this new service using:

```
kubectl get all
```

5. Use the following command to update the nginx reverse proxy and restart it:

```
cat > /etc/nginx/sites-enabled/nginx-reverse-proxy << EOF; systemctl reload nginx
server {
  listen 8080;
  location / {
    proxy_pass "http://174.138.56.240:30498/";
  }
}
EOF
```

where `30498` is the nodeport of the new service. This command will shift the users to the newly created service.

6. Now connect to the worker node where the original service is running. Then use the following commands to patch the `apache-service`.

Get the Container ID of the `apache-deployment1` using:
```
docker ps
```

Then use this command to connect to the container and patch it:

```
docker exec -it 39a938658549 bash
apt-get -y update && apt-get -y upgrade
```

You can check the openssl version before updating it and after updating it using `openssl version` command. Also, a quick rise in the resource usage can be observed using `collectd-web` at this point.

7. Now you can wait for another 10 minutes for resource usage to stabilize if you want to analyze data later. Otherwise continue to next step.

8. Get the traffic back to the original service using:

```
cat > /etc/nginx/sites-enabled/nginx-reverse-proxy << EOF; systemctl reload nginx
server {
  listen 8080;
  location / {
    proxy_pass "http://174.138.56.240:31369/";
  }
}
EOF
```

Here `31369` is the nodeport of original service.

9. Wait for 10 more minutes and then get the csv files which collectd has created and then analyze it for overhead analysis.

## Work contribution:

## Repository files description:

The main files are `kubernetes_setup.yml` and `roles` folder. It is an ansible playbook to make a kubernetes cluster and deploy an application on it. It has description of tasks on the first line of each task.

Other files (`token`, `.ansible.cfg`) are used by the above playbook. You can use `delete_droplets.yml` to quickly destroy digitalocean VMs reserved for the master/worker nodes or you can manually destroy them on the [digitalocean website](https://www.digitalocean.com).
