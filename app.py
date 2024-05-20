from urllib.request import urlopen
import re as r
import requests
import json

def getIP():
    d = str(urlopen('http://checkip.dyndns.com/').read())

    return r.compile(r'Address: (\d+\.\d+\.\d+\.\d+)').search(d).group(1)

ip = getIP() + '/32'

# Authentication
tenant_id = ""
client_id = ""
client_secret = ""
resource = 'https://graph.microsoft.com/'

token_url = f'https://login.microsoftonline.com/{tenant_id}/oauth2/token'
token_data = {
    'grant_type': 'client_credentials',
    'client_id': client_id,
    'client_secret': client_secret,
    'resource': resource
}

token_response = requests.post(token_url, data=token_data)
access_token = token_response.json()['access_token']

# Get Policy ID
namelocation_name = 'Group Homes'
namelocation_id = None

# Get the Policy ID based on Policy Name
namedLocations_list_url = f'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations'
headers = {
    'Authorization': 'Bearer ' + access_token,
    'Content-Type': 'application/json'
}

response = requests.get(namedLocations_list_url, headers=headers)
if response.status_code == 200:
    namedLocations_list_list = response.json().get('value', [])
    for namelocation in namedLocations_list_list:
        if namelocation['displayName'] == namelocation_name:
            namelocation_id = namelocation['id']
            break

url = f'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/{namelocation_id}'
headers = {
    'Authorization': f'Bearer {access_token}',
    'Content-Type': 'application/json'
}

# Get the current list of IP ranges
response = requests.get(url, headers=headers)
ip_named_location = response.json()

# Get the current ipRanges
current_ip_ranges = ip_named_location.get('ipRanges', [])

# Append the new IP address to the current list of IP ranges
new_ip_range = {
    '@odata.type': '#microsoft.graph.iPv4CidrRange',
    'cidrAddress': ip
}
updated_ip_ranges = current_ip_ranges + [new_ip_range]

# Prepare the payload with the updated IP ranges
payload = {
    '@odata.type': '#microsoft.graph.ipNamedLocation',
    'ipRanges': updated_ip_ranges
}

# Update the IP named location
response = requests.patch(url, headers=headers, json=payload)

