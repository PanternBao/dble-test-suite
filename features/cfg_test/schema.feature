Feature: schema basic config test

  @regression
  Scenario: config with er table and extra no use datanode, reload success #1
    Given add xml segment to node with attribute "{'tag':'schema','kv_map':{'name':'mytest'}}" in "schema.xml"
    """
        <table name="test_table" dataNode="dn1,dn2,dn3,dn4" rule="hash-four" >
            <childTable name="child_table" primaryKey="id" joinKey="id" parentKey="id" />
        </table>
    """
    Given add xml segment to node with attribute "{'tag':'root'}" in "schema.xml"
    """
    <dataNode dataHost="172.100.9.6" database="db3" name="testdn"/>
    """
    Then execute admin cmd "reload @@config_all"

  @regression
  Scenario: config with no use datanode (has counter-part datahost), expect reload success but at present fail, config no use datahost reload success #3
    #schema.xml only has dataNodes,  dble starts successful,
    Given delete the following xml segment
      |file        | parent          | child               |
      |schema.xml  |{'tag':'root'}   | {'tag':'schema'}    |
      |schema.xml  |{'tag':'root'}   | {'tag':'dataHost'}  |
    # todo : dble should start only with <dataNode>
    Then restart dble in "dble-1" failed for
    """
    dataNode dn1 reference dataHost:172.100.9.5 not exists!
    """

    #schema.xml only has <dataHost>,  dble starts successful
    Given delete the following xml segment
      |file        | parent          | child               |
      |schema.xml  |{'tag':'root'}   | {'tag':'dataNode'}  |
    Given add xml segment to node with attribute "{'tag':'root'}" in "schema.xml"
    """
	    <dataHost balance="0" maxCon="100" minCon="10" name="dh1" slaveThreshold="100" switchType="-1">
		    <heartbeat>select user()</heartbeat>
		    <writeHost host="hostM1" password="111111" url="172.100.9.5:3306" user="test">
		    </writeHost>
	    </dataHost>
    """
    Given Restart dble in "dble-1" success

  Scenario: when config file contains illegal label<test/>, reload fail #4
    Given add xml segment to node with attribute "{'tag':'root','prev': 'dataHost'}" in "schema.xml"
    """
	    <test>
	    </test>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
    Reload config failure
    """
  @regression
  Scenario: config <dataNode> with "$" preseting range, reload success #5
    Given delete the following xml segment
      |file        | parent          | child               |
      |schema.xml  |{'tag':'root'}   | {'tag':'schema'}    |
      |schema.xml  |{'tag':'root'}   | {'tag':'dataNode'}  |
      |schema.xml  |{'tag':'root'}   | {'tag':'dataHost'}  |
    Given add xml segment to node with attribute "{'tag':'root'}" in "schema.xml"
     """
    	<schema dataNode="dn1" name="mytest" sqlMaxLimit="100">
		    <table dataNode="dn1,dn2" name="test" type="global" />
	    </schema>
	    <dataNode dataHost="172.100.9.5" database="db$1-2" name="dn$1-2" />
	    <dataHost balance="0" maxCon="100" minCon="10" name="172.100.9.5" slaveThreshold="100" switchType="-1">
		    <heartbeat>select user()</heartbeat>
		    <writeHost host="hostM1" password="111111" url="172.100.9.5:3306" user="test">
		    </writeHost>
	    </dataHost>
    """
    Then execute admin cmd "Reload @@config_all"
    Then execute sql in "dble-1" in "user" mode
     | user | passwd | conn   | toClose  | sql                         | expect  | db     |
     | test | 111111 | conn_0 | False    | drop table if exists test   | success | mytest |
     | test | 111111 | conn_0 | True     | create table test(id int)    | success | mytest |

  Scenario: config readhost xml node closed with none abbr mode, expect reload success, but fail at present #6
    Given add xml segment to node with attribute "{'tag':'dataHost/writeHost','kv_map':{'host':'hostM2'}}" in "schema.xml"
    """
    <readHost host="hostM1" password="111111" url="172.100.9.2:3306" user="test">
	</readHost>
    """
    #todo: reload should success
    Then execute admin cmd "reload @@config_all" get the following output
    """
    Reload config failure
    """
  Scenario:.when <readHost> put outside <wirteHost>, reload fail #7
    Given add xml segment to node with attribute "{'tag':'dataHost'}" in "schema.xml"
    """
    <readHost host="hostS1" password="111111" url="172.100.9.2:3306" user="test"/>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
    Reload config failure
    """
  @regression
  Scenario: config table sharding rule not defined in rule.xml, reload fail #8
    Given add xml segment to node with attribute "{'tag':'schema'}" in "schema.xml"
    """
	<table dataNode="dn1,dn2" name="test" rule="sharding-test" />
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
    Reload config failure
    """

  @smoke
  Scenario:github issue 598-636,database configed for datanode is not created and the datanode is not used by any table #9
    Given delete the following xml segment
      |file        | parent          | child               |
      |schema.xml  |{'tag':'root'}   | {'tag':'schema'}    |
      |schema.xml  |{'tag':'root'}   | {'tag':'dataNode'}  |
      |schema.xml  |{'tag':'root'}   | {'tag':'dataHost'}  |
    Given add xml segment to node with attribute "{'tag':'root'}" in "schema.xml"
    """
    	<schema dataNode="dn5" name="mytest" sqlMaxLimit="100">
		    <table dataNode="dn1,dn2,dn3,dn4" name="test" rule="hash-four" />
	    </schema>

	    <dataNode dataHost="172.100.9.5" database="da1" name="dn1" />
	    <dataNode dataHost="172.100.9.6" database="da1" name="dn2" />
	    <dataNode dataHost="172.100.9.5" database="da2" name="dn3" />
	    <dataNode dataHost="172.100.9.6" database="da2" name="dn4" />
	    <dataNode dataHost="172.100.9.5" database="da3" name="dn5" />
    """
    Then execute sql in "mysql-master1"
        | user | passwd | conn   | toClose  | sql                         | expect   | db     |
        | test | 111111 | conn_0 | True     | drop database if exists da1 | success  |         |
        | test | 111111 | conn_0 | True     | drop database if exists da2 | success  |         |
        | test | 111111 | conn_0 | True     | drop database if exists da3 | success  |         |
    Then execute sql in "mysql-master2"
        | user | passwd | conn   | toClose  | sql                         | expect   | db     |
        | test | 111111 | conn_0 | True     | drop database if exists da1 | success  |         |
        | test | 111111 | conn_0 | True     | drop database if exists da2 | success  |         |
    Then execute admin cmd "reload @@config_all"
    Then execute sql in "dble-1" in "admin" mode
        | user  | passwd    | conn   | toClose | sql            | expect  | db     |
        | root  | 111111    | conn_0 | True    | show @@version | success | mytest |
    Then execute sql in "dble-1" in "user" mode
        | user | passwd | conn   | toClose | sql                             | expect   | db      |
        | test | 111111 | conn_0 | True    | create table if not exists test(id int,name varchar(20))    | Unknown database  | mytest |

  @regression
  Scenario: database configed for datanode is not created and the datanode is used by table #10
     Given delete the following xml segment
      |file        | parent          | child               |
      |schema.xml  |{'tag':'root'}   | {'tag':'schema'}    |
      |schema.xml  |{'tag':'root'}   | {'tag':'dataNode'}  |
      |schema.xml  |{'tag':'root'}   | {'tag':'dataHost'}  |
     Given add xml segment to node with attribute "{'tag':'root'}" in "schema.xml"
     """
    	<schema dataNode="dn1" name="mytest" sqlMaxLimit="100">
		    <table dataNode="dn1,dn3" name="test" type="global" />
	    </schema>
	    <dataNode dataHost="dh1" database="da1" name="dn1" />
	    <dataNode dataHost="dh1" database="da2" name="dn3" />
	    <dataHost balance="0" maxCon="100" minCon="10" name="dh1" slaveThreshold="100" switchType="-1">
		    <heartbeat>select user()</heartbeat>
		    <writeHost host="hostM1" password="111111" url="172.100.9.5:3306" user="test">
		    </writeHost>
	    </dataHost>
      """
    Then execute sql in "mysql-master1"
        | user | passwd | conn   | toClose  | sql                                 | expect    | db |
        | test | 111111 | conn_0 | False    | drop database if exists da1         | success   |  |
        | test | 111111 | conn_0 | False    | drop database if exists da2         | success   |  |
    Given Restart dble in "dble-1" success
    Then execute sql in "dble-1" in "admin" mode
        | user  | passwd    | conn   | toClose | sql            | expect  | db     |
        | root  | 111111    | conn_0 | True    | show @@version | success | mytest |
    Then execute sql in "dble-1" in "user" mode
        | user | passwd | conn   | toClose | sql                             | expect   | db      |
        | test | 111111 | conn_0 | True    | create table if not exists test(id int,name varchar(20))    | Unknown database  | mytest |
