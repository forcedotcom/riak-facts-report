Stores your Puppet facts (including custom facts) in a Riak database
----
To allow querying the inventory service, you need to add ACL support to your puppet

**auth.conf**

```
path /facts
auth no
allow *
```
