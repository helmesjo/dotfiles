on open location this_URL
    set workDomains to { ¬
        "azure.com", ¬
        "dynamics.com", ¬
        "login.microsoftonline.com", ¬
        "microsoft.com", ¬
        "office.com", ¬
        "portal.azure.com", ¬
        "powerbi.com", ¬
        "sharepoint.com", ¬
        "teams.com" ¬
    }
    set isWork to false
    repeat with domain in workDomains
        if this_URL contains domain then
            set isWork to true
            exit repeat
        end if
    end repeat
    if isWork then
        do shell script "open -a 'Microsoft Edge' " & quoted form of this_URL
    else
        do shell script "open -a 'Zen' " & quoted form of this_URL
    end if
end open location
