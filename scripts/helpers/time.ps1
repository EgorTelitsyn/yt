# Time formatting helper for clip scripts

function Format-Time($t) {
    $parts = $t -split ":"
    $h = [int]$parts[0]; $m = [int]$parts[1]; $s = [int]$parts[2]
    if ($h -gt 0) { "${h}h${m}m${s}s" }
    elseif ($m -gt 0) { "${m}m${s}s" }
    else { "${s}s" }
}
