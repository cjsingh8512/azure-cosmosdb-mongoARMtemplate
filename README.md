# Install MongoDB Sharding Cluster

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fcjsingh8512%2Fazure-cosmosdb-mongoARMtemplate%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>
<a href="
http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fcjsingh8512%2Fazure-cosmosdb-mongoARMtemplate%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png"/>
</a>


This template deploys a MongoDB Sharding Cluster on CentOS. It deploys 1 router server, one config server replica set with 3 nodes, and 1 shard which is a replica set with 4 nodes. So it totally deploys 8 nodes.

The router server is exposed on public IP address that you can access through SSH on the standard port, also mongodb port 27017 open. You can access it for MongoDB data write and read.

The config server replica set stores sharding cluster metadata. MongoDB suggests to use a replica set for the metadata store in the production environment, in case one of the config server is down, there will still be other 2 config server nodes offer the service.

1 shard is a 4 node replica set. You can shard the data on the replica set. You can also add more replica sets into the sharding cluster.

The nodes are under the same subnet 10.0.0.0/24. Except the router server, the other nodes only have private IP address.

<img src="https://raw.githubusercontent.com/cjsingh8512/azure-cosmosdb-mongoARMtemplate/master/images/Mongo Sharded Cluster.png" />

##Important Notice
Each VM of the shard uses raid0 to improve performance. The number and the size of data disks(setup raid0) on each shard VM are determined by yourself. However, there is number and size of data disks limit per the VM size. Before you set number and size of data disks, please refer to the link https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-sizes/ for the correct choice.

##After deployment, you can do below to verify if the sharding cluster really works or not:

1. SSH connect to the router server, execute below:
  ```
  $mongo -u "<mongouser>" -p "<mongopassword>" "admin"

  db.runCommand( { listshards : 1 } )

  exit
  ```

  Upper db.runCommand( { listshards : 1 } ) command will show the sharding cluster details. 

2. You can "shard" any database and collections you want. SSH connect to the router server, execute below:
  ```
  $mongo -u "<mongouser>" -p "<mongopassword>" "admin"

  db.runCommand({enableSharding: "<database>" })

  sh.status()

  sh.shardCollection("<database>.<collection>", shard-key-pattern)

  exit
  ```

3. You can add more shards into this sharding cluster. SSH connect to one of the router server, execute below:
  ```
  $mongo -u "<mongouser>" -p "<mongopassword>" "admin"

  sh.addShard("<replica set name>/<primary ip>:27017")   

  exit
  ```

  Before adding your own replica set into the sharding cluster, you should enable internal authentication in your replica set first, and make sure the replica set is accessiable through this sharding cluster.

##Known Limitations
- The MongoDB version is 3.6.
- We expose 1 router server on public address so that you can access MongoDB service through internet directly.
- This cluster only has 1 shard, you can add more shards after the deployment. 
- The nodes use internal authentication and ssl. So if you want to add your own replica set into this sharding cluster, you should enable the internal authentication and bring it up in ssl mode first. Check any node /etc/mongokeyfile for more details.
- The replica set is composed with 1 primary node, 3 secondary nodes.
- More MongoDB usage details please visit MongoDB website https://www.mongodb.org/ .

