function Parse-AzResourceID{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]$ResourceID
    )   
    process{
        [hashtable]$return = @{}

        $Pattern = $ResourceID -split "/"
        $return.SubscriptionID = $Pattern[2]
        $return.ResourceGroup = $Pattern[4]
        $return.Resource = $Pattern[8]
    }
    end{
        if($Pattern.Length -gt 0){
            $return
        }
        else{
            Write-host "fsdfsdf"
        }
    }
}