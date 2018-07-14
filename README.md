# mob_framework
Genero Mobile Framework / Demo with Web Service backend.

The is a working mobile application demo that uses RESTFUL web service calls.

The demos features both the mobile and the backend programs and services.
It's currently using the same database as the njms_demos310.

I've attempted to seperate the 'application' specific code from the generic mobile code.

Currently from Mobile app:
* login and get a 'token'
* get a list of customer
* get details for customer
* allow you do choose/take multiple photos/videos and send them to the server.

From the server:
* Handle login and tokens
* supply a list of customers
* supply customer details
* accept photo and video files and produce a thumbnail for the photos.
* provide a simple ui program to view the access / media / data captured by the service.
* provide a simple gallery view for the photos send

Backend Databases:
* Informix
* PostgreSQL
* Maria DB


For PostgreSQL
        sudo -u postgres createuser <appuser>
        sudo -u postgres createdb njm_demo310
        sudo -u postgres psql
        psql (9.6.7)
        Type "help" for help.

        postgres=# grant all privileges on database njm_demo310 to <appuser>;
        GRANT
        postgres=# \q


For MariaDB added a user of 'dbuser' to connect to the database.
MariaDB [(none)]> CREATE USER 'dbuser'@'%';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON *.* TO 'dbuser'@'%';

