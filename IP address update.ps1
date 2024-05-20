# Function to get the public IP address
function Get-PublicIP {
    try {
        $response = Invoke-WebRequest -Uri 'http://checkip.dyndns.com/'
        if ($response.StatusCode -eq 200) {
            $ip = [regex]::Match($response.Content, 'Address: (\d+\.\d+\.\d+\.\d+)').Groups[1].Value
            return $ip + '/32'
        } else {
            throw "Failed to retrieve public IP address"
        }
    } catch {
        Write-Error "Error getting public IP: $_"
        exit 1
    }
}

# Authentication
$tenant_id = ""
$client_id = ""
$client_secret = ""
$resource = 'https://graph.microsoft.com/'

$token_url = "https://login.microsoftonline.com/$tenant_id/oauth2/token"
$token_data = @{
    grant_type    = 'client_credentials'
    client_id     = $client_id
    client_secret = $client_secret
    resource      = $resource
}

try {
    $token_response = Invoke-RestMethod -Method Post -Uri $token_url -ContentType 'application/x-www-form-urlencoded' -Body $token_data
    $access_token = $token_response.access_token
} catch {
    Write-Error "Error obtaining access token: $_"
    exit 1
}

# Get Policy ID
$namelocation_name = 'Group Homes'
$namelocation_id = $null

# Get the Policy ID based on Policy Name
$namedLocations_list_url = 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations'
$headers = @{
    'Authorization' = "Bearer $access_token"
    'Content-Type'  = 'application/json'
}

try {
    $response = Invoke-RestMethod -Uri $namedLocations_list_url -Headers $headers
    if ($response.value) {
        foreach ($namelocation in $response.value) {
            if ($namelocation.displayName -eq $namelocation_name) {
                $namelocation_id = $namelocation.id
                break
            }
        }
    }

    if (-not $namelocation_id) {
        throw "Named location '$namelocation_name' not found"
    }
} catch {
    Write-Error "Error retrieving named location: $_"
    exit 1
}

$url = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$namelocation_id"

# Get the current list of IP ranges
try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers
    $ip_named_location = $response

    # Get the current ipRanges
    $current_ip_ranges = $ip_named_location.ipRanges

    # Append the new IP address to the current list of IP ranges
    $new_ip_range = @{
        '@odata.type' = '#microsoft.graph.iPv4CidrRange'
        'cidrAddress' = (Get-PublicIP)
    }
    $updated_ip_ranges = $current_ip_ranges + $new_ip_range

    # Prepare the payload with the updated IP ranges
    $payload = @{
        '@odata.type' = '#microsoft.graph.ipNamedLocation'
        'ipRanges'    = $updated_ip_ranges
    }

    # Update the IP named location
    $update_response = Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body ($payload | ConvertTo-Json -Depth 4)

    Write-Output "IP address successfully updated in the named location."
} catch {
    Write-Error "Error updating IP address in named location: $_"
    exit 1
}
