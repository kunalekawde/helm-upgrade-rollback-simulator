#!/bin/bash

# Example input for each chart
# JSON array format: ["chart-name", "chart-path", "override-file", "timeout"]
charts_input=(
    '["app-good-1", "app-good-0.1.0.tgz", "/path-to/app-good-override.yaml", "10m"]'
    '["app-bad", "app-bad-0.1.0.tgz", "", "2m"]'
    '["app-good-2", "app-good-0.1.0.tgz", "", ""]'
)

#chart_repo="http://docker.io/charts/"
chart_repo="/local-path"
rollback_policy="rollback"  # Set to "pause" or "rollback"

# Convert JSON strings to an array
charts=()
for input_str in "${charts_input[@]}"; do
    # Use jq for JSON parsing
    chart=$(echo $input_str | jq -c .)
    echo "Input $chart"
    charts+=("$chart")
done

# Select a release to inject failure
upgraded_charts=()  # Array to store successfully upgraded charts

# Function to upgrade Helm chart
upgrade_chart() {
    chart_info=$1
    chart=($(echo $chart_info | jq -c -r '.[] | select(length > 0) // []'))

    release_name=${chart[0]}
    chart_name=${chart[1]}
    chart_path="${chart_repo}${chart_name}"  # Append chart_repo to chart_path
    override_file=${chart[2]}
    timeout=${chart[3]}
    
    if [ "$timeout" == "[]" ]; then
        timeout="5m"  # Default timeout if not specified
    fi

    echo "Upgrading release: $release_name with chart: $chart_path, override: $override_file, timeout: $timeout"

    if [ "$override_file" == "[]" ]; then
        helm upgrade $release_name $chart_path --timeout "$timeout"
    else
        helm upgrade $release_name $chart_path --timeout "$timeout" -f "$override_file"
    fi

    # Check the result of the helm upgrade command
    if [ $? -ne 0 ]; then
        echo "Failed to upgrade release: $release_name with chart: $chart_path"
        upgraded_charts+=("$release_name")
        rollback_charts
        exit 1  # Dont continue post rollback 
    else
        # Store the successfully upgraded chart
        echo "Store the upgraded chart: $release_name"
        upgraded_charts+=("$release_name")
        run_tests "$release_name" "$timeout" "$override_file"
    fi
}


# Function to rollback Helm charts
rollback_charts() {
    # Check rollback policy
    if [ "$rollback_policy" == "pause" ]; then
        chart="${upgraded_charts[-1]}"
        echo "Pausing on failure. Rolling back to the previous versions of chart: $chart"
        helm rollback $chart 0
        exit 1  # Pause on failure
    elif [ "$rollback_policy" == "rollback" ]; then
        echo "Rolling back to the previous versions of charts in the following order:"
        for ((i=${#upgraded_charts[@]}-1; i>=0; i--)); do
            chart=${upgraded_charts[i]}
            echo "$chart"
        done
        for ((i=${#upgraded_charts[@]}-1; i>=0; i--)); do
            chart=${upgraded_charts[i]}
            echo "Rolling back chart: $chart"
            helm rollback $chart 0
        done
    fi
}

# Function to run Helm tests
run_tests() {
    release_name=$1
    timeout=$2
    override_file=$3

    echo "Running Helm tests for release: $release_name"
    helm test $release_name --timeout $timeout

    # Check the result of the helm test command
    if [ $? -ne 0 ]; then
        echo "Helm tests failed for release: $release_name"
        rollback_charts
    else
        echo "Helm tests passed for release: $release_name"
    fi
}

# Loop through each chart and upgrade
for chart_info in "${charts[@]}"; do
    upgrade_chart "$chart_info"
done

echo "Helm upgrade sequence completed successfully."

