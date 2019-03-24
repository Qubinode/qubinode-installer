# Stores the dns-key used for this OpenShift Deployment

## Example
```
cat <<YAML > dns_server/dns_key/dns_key
---
vault_dns_key: "dummy_key=="

YAML

echo "ansible-vault-password" >   ansible-vault.pass

ansible-vault encrypt dns_server/dns_key/dns_key   --vault-password-file=ansible-vault.pass
```
