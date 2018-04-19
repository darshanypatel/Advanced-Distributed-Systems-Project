db.createUser(
    {
      user: "myUserAdmin",
      pwd: "abc123",
      roles: [
         { role: "userAdminAnyDatabase", db: "admin" }
      ]
    }
,
    {
        w: "majority",
        wtimeout: 5000
    }
);
db.createCollection("test");
