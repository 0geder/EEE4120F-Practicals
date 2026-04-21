# OpenMP Data Collection Script
$Results = @()

for ($cities = 4; $cities -le 10; $cities++) {
    for ($threads = 1; $threads -le 8; $threads = $threads * 2) {
        Write-Host "Testing $cities cities with $threads threads..."
        
        for ($run = 1; $run -le 5; $run++) {
            Write-Host "  Run $run"
            $output = .\wariara_f_OpenMP.exe -p $threads -i input\energy$cities -o output\temp.txt 2>&1
            
            # Extract computation time
            if ($output -match "Comp Time\s+\(Tcomp\)\s*:\s*([\d.]+)\s*s") {
                $compTime = [double]$matches[1] * 1000  # Convert to ms
                $Results += [PSCustomObject]@{
                    Cities = $cities
                    Threads = $threads
                    Run = $run
                    CompTime_ms = $compTime
                }
            }
        }
    }
}

$Results | Export-Csv -Path "openmp_results.csv" -NoTypeInformation
Write-Host "OpenMP data collection complete."
