#!/usr/bin/env python3
"""
Azure Cost Aggregation Script
Recursively searches for files containing 'diff' in ~/Downloads/finops directory,
extracts amortized cost data, aggregates across subscriptions, and generates
a consolidated report with month-over-month comparisons.
"""

import os
import json
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple, Optional
from datetime import datetime


class AzureCostAggregator:
    def __init__(self, base_dir: str):
        self.base_dir = Path(base_dir).expanduser()
        self.subscription_data = defaultdict(lambda: {
            'november': {'total': 0.0, 'currency': 'EUR', 'file': None},
            'december': {'total': 0.0, 'currency': 'EUR', 'file': None},
            'diff_file': None
        })
        
    def find_diff_files(self) -> List[Path]:
        """Recursively find all files containing 'diff' in their filename."""
        diff_files = []
        for root, dirs, files in os.walk(self.base_dir):
            for file in files:
                if 'diff' in file.lower():
                    diff_files.append(Path(root) / file)
        return sorted(diff_files)
    
    def extract_subscription_id(self, filename: str) -> Optional[str]:
        """Extract Azure subscription ID (UUID format) from filename."""
        # Match UUID pattern: 8-4-4-4-12 hex digits
        pattern = r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
        match = re.search(pattern, filename.lower())
        return match.group(1) if match else None
    
    def parse_json_cost_file(self, json_path: Path) -> Optional[float]:
        """Parse JSON file and extract total cost."""
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if 'totals' in data and 'totalCostInTimeframe' in data['totals']:
                    return float(data['totals']['totalCostInTimeframe'])
        except (json.JSONDecodeError, FileNotFoundError, KeyError) as e:
            print(f"Warning: Could not parse {json_path}: {e}")
        return None
    
    def parse_diff_text_file(self, diff_path: Path) -> Tuple[Optional[float], Optional[float]]:
        """Parse diff text file and extract source (Nov) and target (Dec) costs."""
        try:
            with open(diff_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Look for the TOTAL COSTS line in the Summary section
            # Pattern: | TOTAL COSTS | 9,499.42 EUR | 1,620.68 EUR | -7,878.74 EUR |
            pattern = r'\|\s*TOTAL COSTS\s*\|\s*([\d,]+\.\d+)\s*EUR\s*\|\s*([\d,]+\.\d+)\s*EUR'
            match = re.search(pattern, content)
            
            if match:
                source_cost = float(match.group(1).replace(',', ''))
                target_cost = float(match.group(2).replace(',', ''))
                return source_cost, target_cost
        except (FileNotFoundError, ValueError) as e:
            print(f"Warning: Could not parse {diff_path}: {e}")
        
        return None, None
    
    def find_related_json_files(self, diff_file: Path, sub_id: str) -> Tuple[Optional[Path], Optional[Path]]:
        """Find corresponding November and December JSON files for a subscription."""
        parent_dir = diff_file.parent
        
        # Look for november/november-{sub_id}.json and december/december-{sub_id}.json
        nov_patterns = [
            parent_dir / f"november-{sub_id}.json",
            parent_dir / f"nov-{sub_id}.json",
            parent_dir / f"september-{sub_id}.json",
            parent_dir / f"sept-{sub_id}.json",
        ]
        
        dec_patterns = [
            parent_dir / f"december-{sub_id}.json",
            parent_dir / f"dec-{sub_id}.json",
            parent_dir / f"october-{sub_id}.json",
            parent_dir / f"oct-{sub_id}.json",
        ]
        
        nov_file = next((p for p in nov_patterns if p.exists()), None)
        dec_file = next((p for p in dec_patterns if p.exists()), None)
        
        return nov_file, dec_file
    
    def process_all_files(self):
        """Process all diff files and extract cost data."""
        diff_files = self.find_diff_files()
        print(f"Found {len(diff_files)} files containing 'diff' in filename\n")
        
        for diff_file in diff_files:
            sub_id = self.extract_subscription_id(diff_file.name)
            if not sub_id:
                print(f"Skipping {diff_file.name}: No subscription ID found")
                continue
            
            print(f"Processing subscription: {sub_id}")
            print(f"  Diff file: {diff_file.name}")
            
            # Store diff file reference
            self.subscription_data[sub_id]['diff_file'] = str(diff_file)
            
            # Try to parse diff file for costs
            source_cost, target_cost = self.parse_diff_text_file(diff_file)
            
            # Find related JSON files
            nov_file, dec_file = self.find_related_json_files(diff_file, sub_id)
            
            # Extract costs from JSON files if available
            if nov_file:
                nov_cost = self.parse_json_cost_file(nov_file)
                if nov_cost is not None:
                    self.subscription_data[sub_id]['november']['total'] = nov_cost
                    self.subscription_data[sub_id]['november']['file'] = str(nov_file)
                    print(f"  November JSON: {nov_file.name} -> {nov_cost:.2f} EUR")
            elif source_cost is not None:
                self.subscription_data[sub_id]['november']['total'] = source_cost
                print(f"  November (from diff): {source_cost:.2f} EUR")
            
            if dec_file:
                dec_cost = self.parse_json_cost_file(dec_file)
                if dec_cost is not None:
                    self.subscription_data[sub_id]['december']['total'] = dec_cost
                    self.subscription_data[sub_id]['december']['file'] = str(dec_file)
                    print(f"  December JSON: {dec_file.name} -> {dec_cost:.2f} EUR")
            elif target_cost is not None:
                self.subscription_data[sub_id]['december']['total'] = target_cost
                print(f"  December (from diff): {target_cost:.2f} EUR")
            
            print()
    
    def calculate_aggregates(self) -> Dict:
        """Calculate aggregate statistics across all subscriptions."""
        total_nov = 0.0
        total_dec = 0.0
        
        for sub_id, data in self.subscription_data.items():
            total_nov += data['november']['total']
            total_dec += data['december']['total']
        
        change = total_dec - total_nov
        percent_change = (change / total_nov * 100) if total_nov != 0 else 0.0
        
        return {
            'total_november': total_nov,
            'total_december': total_dec,
            'total_change': change,
            'percent_change': percent_change,
            'subscription_count': len(self.subscription_data)
        }
    
    def format_currency(self, amount: float) -> str:
        """Format currency with proper thousands separators and 2 decimal places."""
        return f"{amount:,.2f} EUR"
    
    def format_change(self, amount: float) -> str:
        """Format change amount with +/- sign."""
        sign = "+" if amount >= 0 else ""
        return f"{sign}{amount:,.2f} EUR"
    
    def format_percentage(self, percent: float) -> str:
        """Format percentage with +/- sign and 2 decimal places."""
        sign = "+" if percent >= 0 else ""
        return f"{sign}{percent:.2f}%"
    
    def generate_report(self, output_file: str = "total_amortized_costs_summary.txt"):
        """Generate comprehensive cost report."""
        aggregates = self.calculate_aggregates()
        
        report_lines = []
        report_lines.append("=" * 100)
        report_lines.append("AZURE AMORTIZED COSTS SUMMARY REPORT")
        report_lines.append("=" * 100)
        report_lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"Source Directory: {self.base_dir}")
        report_lines.append(f"Total Subscriptions Analyzed: {aggregates['subscription_count']}")
        report_lines.append("=" * 100)
        report_lines.append("")
        
        # Grand Totals Section
        report_lines.append("GRAND TOTALS - ALL SUBSCRIPTIONS")
        report_lines.append("-" * 100)
        report_lines.append(f"{'Period':<30} {'Total Cost':<25} {'Change':<25} {'% Change':<20}")
        report_lines.append("-" * 100)
        report_lines.append(f"{'November 2025':<30} {self.format_currency(aggregates['total_november']):<25} {'':<25} {'':<20}")
        report_lines.append(f"{'December 2025':<30} {self.format_currency(aggregates['total_december']):<25} "
                          f"{self.format_change(aggregates['total_change']):<25} "
                          f"{self.format_percentage(aggregates['percent_change']):<20}")
        report_lines.append("-" * 100)
        report_lines.append("")
        
        # Per-Subscription Breakdown
        report_lines.append("PER-SUBSCRIPTION BREAKDOWN")
        report_lines.append("=" * 100)
        report_lines.append("")
        
        # Sort subscriptions by December cost (descending)
        sorted_subs = sorted(
            self.subscription_data.items(),
            key=lambda x: x[1]['december']['total'],
            reverse=True
        )
        
        for idx, (sub_id, data) in enumerate(sorted_subs, 1):
            nov_cost = data['november']['total']
            dec_cost = data['december']['total']
            change = dec_cost - nov_cost
            percent_change = (change / nov_cost * 100) if nov_cost != 0 else 0.0
            
            report_lines.append(f"SUBSCRIPTION #{idx}: {sub_id}")
            report_lines.append("-" * 100)
            report_lines.append(f"  November 2025:  {self.format_currency(nov_cost)}")
            report_lines.append(f"  December 2025:  {self.format_currency(dec_cost)}")
            report_lines.append(f"  Change:         {self.format_change(change)} ({self.format_percentage(percent_change)})")
            
            if data['diff_file']:
                report_lines.append(f"  Diff File:      {Path(data['diff_file']).name}")
            if data['november']['file']:
                report_lines.append(f"  Nov JSON:       {Path(data['november']['file']).name}")
            if data['december']['file']:
                report_lines.append(f"  Dec JSON:       {Path(data['december']['file']).name}")
            
            report_lines.append("")
        
        # Summary Statistics
        report_lines.append("=" * 100)
        report_lines.append("SUMMARY STATISTICS")
        report_lines.append("=" * 100)
        
        # Calculate additional statistics
        increases = sum(1 for data in self.subscription_data.values() 
                       if data['december']['total'] > data['november']['total'])
        decreases = sum(1 for data in self.subscription_data.values() 
                       if data['december']['total'] < data['november']['total'])
        unchanged = sum(1 for data in self.subscription_data.values() 
                       if data['december']['total'] == data['november']['total'])
        
        avg_nov = aggregates['total_november'] / aggregates['subscription_count']
        avg_dec = aggregates['total_december'] / aggregates['subscription_count']
        
        report_lines.append(f"Subscriptions with cost increases:  {increases}")
        report_lines.append(f"Subscriptions with cost decreases:  {decreases}")
        report_lines.append(f"Subscriptions with no change:       {unchanged}")
        report_lines.append(f"Average cost per subscription (Nov): {self.format_currency(avg_nov)}")
        report_lines.append(f"Average cost per subscription (Dec): {self.format_currency(avg_dec)}")
        report_lines.append("")
        
        # Month-over-Month Comparison
        report_lines.append("=" * 100)
        report_lines.append("MONTH-OVER-MONTH COMPARISON (November 2025 vs December 2025)")
        report_lines.append("=" * 100)
        report_lines.append(f"Total November Cost:     {self.format_currency(aggregates['total_november'])}")
        report_lines.append(f"Total December Cost:     {self.format_currency(aggregates['total_december'])}")
        report_lines.append(f"Absolute Change:         {self.format_change(aggregates['total_change'])}")
        report_lines.append(f"Percentage Change:       {self.format_percentage(aggregates['percent_change'])}")
        report_lines.append("")
        
        if aggregates['total_change'] > 0:
            report_lines.append(f"⚠️  ALERT: Overall costs INCREASED by {self.format_currency(abs(aggregates['total_change']))}")
        elif aggregates['total_change'] < 0:
            report_lines.append(f"✓  Overall costs DECREASED by {self.format_currency(abs(aggregates['total_change']))}")
        else:
            report_lines.append("→  Overall costs remained UNCHANGED")
        
        report_lines.append("")
        report_lines.append("=" * 100)
        report_lines.append("END OF REPORT")
        report_lines.append("=" * 100)
        
        # Write report to file
        report_content = "\n".join(report_lines)
        output_path = Path(output_file)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(report_content)
        
        print(f"\n✓ Report generated successfully: {output_path.absolute()}")
        print(f"  Total subscriptions: {aggregates['subscription_count']}")
        print(f"  November total: {self.format_currency(aggregates['total_november'])}")
        print(f"  December total: {self.format_currency(aggregates['total_december'])}")
        print(f"  Change: {self.format_change(aggregates['total_change'])} ({self.format_percentage(aggregates['percent_change'])})")
        
        return output_path


def main():
    """Main execution function."""
    print("Azure Cost Aggregation Script")
    print("=" * 100)
    print()
    
    # Initialize aggregator with ~/Downloads/finops directory
    finops_dir = "~/Downloads/finops"
    aggregator = AzureCostAggregator(finops_dir)
    
    # Check if directory exists
    if not aggregator.base_dir.exists():
        print(f"Error: Directory not found: {aggregator.base_dir}")
        print("Please ensure the ~/Downloads/finops directory exists.")
        return 1
    
    print(f"Scanning directory: {aggregator.base_dir}")
    print()
    
    # Process all files
    aggregator.process_all_files()
    
    # Generate report
    if not aggregator.subscription_data:
        print("Warning: No subscription data found. No report generated.")
        return 1
    
    output_file = "total_amortized_costs_summary.txt"
    aggregator.generate_report(output_file)
    
    return 0


if __name__ == "__main__":
    exit(main())
