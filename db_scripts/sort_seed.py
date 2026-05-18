import sys
import re

dump_file = sys.argv[1]
init_order = [
    "ai_generated_recipes_v2",
    "batches",
    "brew_kettles",
    "fermentables",
    "fermenter_controllers",
    "fermenters",
    "fining_agents",
    "hops",
    "malt_depots",
    "miscs",
    "packaging_profiles",
    "recipes",
    "user_profiles",
    "water_profiles",
    "yeast_bank_entries",
    "keezer_configs",
    "how_to_topics",
    "video_instructions"
]

with open(dump_file, 'r') as f:
    lines = f.readlines()

header = []
footer = []
table_chunks = {}
current_table = None

in_data = False

for line in lines:
    match = re.match(r'^-- Data for Name: (\w+);', line)
    if match:
        current_table = match.group(1)
        in_data = True
        table_chunks[current_table] = []
    
    if line.startswith('-- PostgreSQL database dump complete'):
        in_data = False
        current_table = None
        footer.append(line)
        continue

    if not in_data and not current_table:
        header.append(line)
        continue
    
    if in_data and current_table:
        table_chunks[current_table].append(line)

with open(dump_file, 'w') as f:
    f.writelines(header)
    for table in init_order:
        if table in table_chunks:
            f.writelines(table_chunks[table])
        else:
            print(f"Warning: {table} not found in dump")
    
    # Add any tables not in init_order (just in case)
    for table, chunk in table_chunks.items():
        if table not in init_order:
            print(f"Adding unknown table {table}")
            f.writelines(chunk)
            
    f.writelines(footer)

print("Sorted seed data successfully.")
