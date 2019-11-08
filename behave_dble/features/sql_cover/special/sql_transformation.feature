# Created by maofei at 2019/7/25
Feature: #test the correctness of sql transformation

  Scenario: #test the explain result of `limit`
    Then execute sql in "dble-1" in "user" mode
      | user | passwd | conn   | toClose  | sql                                                              | expect    | db     |
      | test | 111111 | conn_0 | True     | drop table if exists sharding_4_t1                          | success   | schema1 |
      | test | 111111 | conn_0 | True     | drop table if exists sharding_3_t1                          | success   | schema1 |
      | test | 111111 | conn_0 | True     | drop table if exists sharding_4_t3                          | success   | schema3 |
      | test | 111111 | conn_0 | True     | drop table if exists global_4_t1                            | success   | schema2 |
      | test | 111111 | conn_0 | True     | create table sharding_4_t1 (id int,c_flag char(255))     | success   | schema1 |
      | test | 111111 | conn_0 | True     | create table sharding_3_t1 (id int,c_flag char(255))     | success   | schema1 |
      | test | 111111 | conn_0 | True     | create table sharding_4_t3 (id int,c_flag char(255))     | success   | schema3 |
      | test | 111111 | conn_0 | True     | create table global_4_t1 (id int,c_flag char(255))       | success   | schema2 |
      | test | 111111 | conn_0 | True     | explain select * from schema1.sharding_4_t1                | hasStr{'SELECT * FROM sharding_4_t1 LIMIT 100'}    | schema1 |
      | test | 111111 | conn_0 | True     | explain select * from schema3.sharding_4_t3               | hasStr{'select * from sharding_4_t3'}    | schema1 |
      | test | 111111 | conn_0 | True     | explain insert into global_4_t1 values(1,1)               | hasStr{insert into `global_4_t1`(`id`,`c_flag`,`_dble_op_time`)}    | schema2 |
      | test | 111111 | conn_0 | True     | explain update global_4_t1 set c_flag=2                    | hasStr{UPDATE global_4_t1 SET c_flag = 2, _dble_op_time}    | schema2 |
      | test | 111111 | conn_0 | True     | explain select distinct(id) from sharding_4_t1             | hasStr{SELECT id FROM sharding_4_t1 GROUP BY id LIMIT 100'}    | schema1 |
      | test | 111111 | conn_0 | True     | explain select 1                                               | hasStr{('dn5', 'BASE SQL', 'select 1'),}    | schema1 |
      | test | 111111 | conn_0 | True     | explain select * from sharding_4_t1,sharding_3_t1         | hasNoStr{LIMIT}    | schema1 |
    Given add xml segment to node with attribute "{'tag':'schema','kv_map':{'name':'schema1'}}" in "schema.xml"
    """
        <table name="table_a" dataNode="dn1,dn2" rule="hash-two" primaryKey="id"/>
        <table name="table_b" dataNode="dn1,dn2" rule="hash-two" needAddLimit="false"/>
    """
    Then execute admin cmd "reload @@config_all"
    Then execute sql in "dble-1" in "user" mode
      | user | passwd | conn   | toClose  | sql                                                 | expect    | db      |
      | test | 111111 | conn_0 | True     | drop table if exists table_a                     | success   | schema1 |
      | test | 111111 | conn_0 | True     | create table table_a (id int,c_flag char(255))| success   | schema1 |
      | test | 111111 | conn_0 | True     | drop table if exists table_b                     | success   | schema1 |
      | test | 111111 | conn_0 | True     | create table table_b (id int,c_flag char(255))| success   | schema1 |
      | test | 111111 | conn_0 | True     | explain select * from table_a where id=1       | has{('dn2', 'BASE SQL', 'select * from table_a where id=1'),}   | schema1 |
      | test | 111111 | conn_0 | True     | explain select * from table_b                    | hasStr{('dn1', 'BASE SQL', 'select * from table_b'),}   | schema1 |
    Given update file content "/opt/dble/conf/cacheservice.properties" in "dble-1"
     """
      s/layedpool.TableID2DataNodeCache=encache,10000,18000/#layedpool.TableID2DataNodeCache=encache,10000,18000/
      s/#layedpool.TableID2DataNodeCacheType=encache/layedpool.TableID2DataNodeCacheType=encache/
    """
    Given Restart dble in "dble-1" success
    Then execute sql in "dble-1" in "user" mode
      | user | passwd | conn   | toClose  | sql                                                             | expect    | db     |
      | test | 111111 | conn_0 | True     | explain select * from global_4_t1                           | hasStr{'SELECT * FROM global_4_t1 LIMIT 100'}   | schema2 |
      | test | 111111 | conn_0 | True     | explain select * from sharding_4_t1                         | hasStr{'SELECT * FROM sharding_4_t1 LIMIT 100'}    | schema1 |
      | test | 111111 | conn_0 | True    | explain select * from table_a where id=1                    | hasStr{'select * from table_a where id=1'}   | schema1 |
      | test | 111111 | conn_0 | True    | explain select * from table_a where c_flag=1                | hasStr{'SELECT * FROM table_a WHERE c_flag = 1 LIMIT 100'}   | schema1 |
      | test | 111111 | conn_0 | True    | explain select * from table_a order by id limit 3,9        | hasStr{ASC LIMIT 12}   | schema1 |
    Given update file content "/opt/dble/conf/cacheservice.properties" in "dble-1"
     """
      s/#layedpool.TableID2DataNodeCache=encache,10000,18000/layedpool.TableID2DataNodeCache=encache,10000,18000/
      s/layedpool.TableID2DataNodeCacheType=encache/#layedpool.TableID2DataNodeCacheType=encache/
    """
