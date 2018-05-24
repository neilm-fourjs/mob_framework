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
