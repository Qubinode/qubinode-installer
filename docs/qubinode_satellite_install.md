```
qubinode-install -p satellite
```

The installation menu

Choose Options:
 - 2) Display other options
 - 4) Satellite - Red Hat Satellite Server
 - Continue with the installation of Satellite? yes/no

  **   IdM server is installed                                                   **
         Url: https://qbn-dns01.lunchnet.example/ipa 
         Username: admin 
         Password: the vault variable *admin_user_password* 

     Run: ansible-vault edit /home/admin/qubinode-installer/playbooks/vars/vault.yml 


 *******************************************************************************
 *  The Satellite server has been deployed with login details below.      *

      Web Url: https://qbn-sat01.lunchnet.example 
      Username: admin 
      Password: the vault variable *admin_user_password* 

      Run: ansible-vault edit /home/admin/qubinode-installer/playbooks/vars/vault.yml