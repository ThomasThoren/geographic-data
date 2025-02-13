
# Naming conventions. Applies to shapefiles, GeoJSON and TopoJSON.
# name-crs                -- Converted to WGS 84 coordinate reference system.
# name-extracted          -- Unzipped contents from a .zip file.
# exports/name-fullsize   -- Full accuracy, but with limited fields.
# exports/name-simplified -- Limited accuracy in order to save on file size.

# All other files should go into a temporary directory.

.SECONDARY:

.PHONY: \
	help \
	municipal-districts \
	parishes \
	precincts \
	state-districts \
	water \
	buildings

help:
	@echo There is no default command. Choose from these commands:
	@echo ''
	@echo '  clean                   -- Delete temporary files.'
	@echo '  help                    -- Show available commands.'
	@echo '  municipal-districts     -- Runs the following commands:'
	@echo '  ├─opsb                  -- Creates Orleans Parish School Board districts.'
	@echo '  ├─orleans-fqedd         -- Creates French Quarter Economic Development District.'
	@echo '  └─orleans-neighborhoods -- Creates neighborhoods.'
	@echo '  buildings               -- Creates buildings and parcels.'
	@echo '  parishes                -- Creates parishes.'
	@echo '  precincts               -- Creates precincts.'
	@echo '  state-districts         -- Runs the following commands:'
	@echo '  ├─bese                  -- Creates Board of Elementary and Secondary Education districts.'
	@echo '  ├─congress              -- Creates U.S. Congress districts.'
	@echo '  └─legislature           -- Creates state legislature districts.'
	@echo '  water                   -- Creates water.'

all: water \
	parishes \
	precincts \
	state-districts \
	municipal-districts \
	buildings

clean:
	@rm -rf tmp

#####################
#                   #
#  State districts  #
#                   #
#####################

state-districts:
	@# TODO: Could remove islands in all files to reduce size.
	@$(MAKE) bese
	@$(MAKE) congress
	@$(MAKE) legislature

########################################################
#  BESE (Board of Elementary and Secondary Education)  #
########################################################

zip/state-districts/bese/%.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'http://house.legis.state.la.us/H_Redistricting2011/ShapfilesAnd2010CensusBlockEquivFiles/Shapefile%20-%20BESE%20-%20Act%202%20(HB519)%20of%20the%202011%20RS.zip'
	@mv $@.download $@

shp/state-districts/bese/%-extracted.shp: zip/state-districts/bese/%.zip
	@mkdir -p $(dir $@)

	@# Extract .zip contents to temporary folder
	@mkdir -p tmp
	@unzip -q -o -d tmp $<

	@for file in tmp/*.*; do \
		fullfile=$$(basename "$$file") && \
		filename=$${fullfile%.*} && \
		fileextension="$${file##*.}" && \
		cp "$$file" "$(dir $@)$*-extracted.$$fileextension" ; \
	done

	@rm -rf tmp

# Convert CRS to WGS 84 (EPSG:4326)
shp/state-districts/bese/%-crs.shp: shp/state-districts/bese/%-extracted.shp
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs "EPSG:4326"

# Remove water geometry
exports/shp/state-districts/bese/%-fullsize.shp: shp/state-districts/bese/%-crs.shp \
	exports/shp/water/gulf-of-mexico-fullsize.shp

	@mkdir -p $(dir $@)
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="bese-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="gulf-of-mexico-fullsize">'\
				'<SrcDataSource>exports/shp/water/gulf-of-mexico-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(bese.GEOMETRY, ST_Buffer(gulf.GEOMETRY, 0.00075)) AS geometry, \
					bese.DISTRICT_I AS district \
				FROM 'bese-crs' AS bese, 'gulf-of-mexico-fullsize' AS gulf"

# Convert SHP to GeoJSON
exports/geojson/state-districts/bese/%-fullsize.json: exports/shp/state-districts/bese/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/state-districts/bese/%-fullsize.json: exports/geojson/state-districts/bese/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/state-districts/bese/%-simplified.json: exports/topojson/state-districts/bese/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-9 \
		-q 1e4 \
		-o $@ \
		-- $<

# Convert simplified TopoJSON to simplified GeoJSON
exports/geojson/state-districts/bese/%-simplified.json: exports/topojson/state-districts/bese/%-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@

# Convert simplified GeoJSON to simplified shapefile
exports/shp/state-districts/bese/%-simplified.shp: exports/geojson/state-districts/bese/%-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<

bese: exports/shp/state-districts/bese/bese-simplified.shp


#############################
#  U.S. Congress districts  #
#############################

# Download zipped shapefiles from House website
zip/state-districts/congress/congress.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'http://www.house.louisiana.gov/H_Redistricting2011/ShapfilesAnd2010CensusBlockEquivFiles/Shapefile%20-%20Congress%20-%20Act%202%20(HB6)%20of%20the%202011%20ES.zip'
	@mv $@.download $@

# Unzip downloaded .zip files.
shp/state-districts/congress/%-extracted.shp: zip/state-districts/congress/%.zip
	@mkdir -p $(dir $@)

	@# Extract .zip contents to temporary folder
	@mkdir -p tmp
	@unzip -q -o -d tmp $<

	@for file in tmp/*.*; do \
		fullfile=$$(basename "$$file") && \
		filename=$${fullfile%.*} && \
		fileextension="$${file##*.}" && \
		cp "$$file" "$(dir $@)$*-extracted.$$fileextension" ; \
	done

	@rm -rf tmp

# Fix CRS
shp/state-districts/congress/%-crs.shp: shp/state-districts/congress/%-extracted.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs "EPSG:4326"

# Remove water
exports/shp/state-districts/congress/congress-fullsize.shp: shp/state-districts/congress/congress-crs.shp \
	exports/shp/water/gulf-of-mexico-fullsize.shp

	@mkdir -p $(dir $@)
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="congress-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
				'<OGRVRTLayer name="gulf-of-mexico-fullsize">'\
					'<SrcDataSource>exports/shp/water/gulf-of-mexico-fullsize.shp</SrcDataSource>'\
				'</OGRVRTLayer>'\
			'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(congress.GEOMETRY, ST_Buffer(gulf.GEOMETRY, 0.0000001)) AS geometry, \
					congress.DISTRICT_I AS district \
				FROM 'congress-crs' AS congress, 'gulf-of-mexico-fullsize' AS gulf"

# Convert SHP to GeoJSON
exports/geojson/state-districts/congress/%-fullsize.json: exports/shp/state-districts/congress/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/state-districts/congress/%-fullsize.json: exports/geojson/state-districts/congress/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/state-districts/congress/%-simplified.json: exports/topojson/state-districts/congress/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-8 \
		-q 1e4 \
		-o $@ \
		-- $<

# Convert simplified TopoJSON to simplified GeoJSON
exports/geojson/state-districts/congress/%-simplified.json: exports/topojson/state-districts/congress/%-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@

# Convert simplified GeoJSON to simplified shapefile
exports/shp/state-districts/congress/%-simplified.shp: exports/geojson/state-districts/congress/%-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<

congress: exports/shp/state-districts/congress/congress-simplified.shp

#######################
#  State legislature  #
#######################

# Download zipped shapefiles from House website
zip/state-districts/legislature/house.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'http://www.house.louisiana.gov/H_Redistricting2011/ShapfilesAnd2010CensusBlockEquivFiles/Shapefile%20-%20House%20-%20Act%201%20(HB1)%20of%20the%202011%20ES.zip'
	@mv $@.download $@
zip/state-districts/legislature/senate.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'http://www.house.louisiana.gov/H_Redistricting2011/ShapfilesAnd2010CensusBlockEquivFiles/Shapefile%20-%20Senate%20-%20Act%2024%20(SB1)%20of%20the%202011%20ES.zip'
	@mv $@.download $@

# Unzip downloaded .zip files.
shp/state-districts/legislature/%-extracted.shp: zip/state-districts/legislature/%.zip
	@mkdir -p $(dir $@)

	@# Extract .zip contents to temporary folder
	@mkdir -p tmp
	@unzip -q -o -d tmp $<

	@for file in tmp/*.*; do \
		fullfile=$$(basename "$$file") && \
		filename=$${fullfile%.*} && \
		fileextension="$${file##*.}" && \
		cp "$$file" "$(dir $@)$*-extracted.$$fileextension" ; \
	done

	@rm -rf tmp

# Fix CRS
shp/state-districts/legislature/%-crs.shp: shp/state-districts/legislature/%-extracted.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs "EPSG:4326"

# Remove water
exports/shp/state-districts/legislature/house-fullsize.shp: shp/state-districts/legislature/house-crs.shp \
	exports/shp/water/lake-pontchartrain-fullsize.shp \
	exports/shp/water/gulf-of-mexico-fullsize.shp

	@mkdir -p $(dir $@)
	@mkdir -p tmp

	@# Remove Lake Pontchartrain
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="house-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="lake-pontchartrain-fullsize">'\
				'<SrcDataSource>exports/shp/water/lake-pontchartrain-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/house-no-lake.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(house.GEOMETRY, lake.GEOMETRY) AS geometry, \
					house.* \
				FROM 'house-crs' AS house, 'lake-pontchartrain-fullsize' AS lake"

	@# A. This method takes about xx minutes.
	@# A-1.) Diffing only coastal precincts and Gulf of Mexico
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="house-no-lake">'\
				'<SrcDataSource>tmp/house-no-lake.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="gulf-of-mexico-fullsize">'\
				'<SrcDataSource>exports/shp/water/gulf-of-mexico-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			shp/state-districts/legislature/house-coastal-diff.shp /vsistdin/ \
			-overwrite \
			-dialect sqlite \
			-sql "SELECT ST_Difference(house.GEOMETRY, ST_Buffer(gulf.GEOMETRY, 0.0000001)) AS geometry, \
					house.* \
				FROM 'house-no-lake' as house, 'gulf-of-mexico-fullsize' AS gulf \
				WHERE OBJECTID = '47' OR \
					OBJECTID = '49' OR \
					OBJECTID = '50' OR \
					OBJECTID = '51' OR \
					OBJECTID = '53' OR \
					OBJECTID = '54' OR \
					OBJECTID = '84' OR \
					OBJECTID = '103' OR \
					OBJECTID = '105'"
	@# A-2.) Removing coastal precincts from Louisiana precincts
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		shp/state-districts/legislature/house-non-coastal.shp tmp/house-no-lake.shp \
		-overwrite \
		-where 'OBJECTID != "47" AND \
			OBJECTID != "49" AND \
			OBJECTID != "50" AND \
			OBJECTID != "51" AND \
			OBJECTID != "53" AND \
			OBJECTID != "54" AND \
			OBJECTID != "84" AND \
			OBJECTID != "103" AND \
			OBJECTID != "105"'
	@# A-3.) Joining the two files (Louisiana precincts minus coastal precincts
	@# and the land-only portion of coastal precincts).
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		-update \
		-append \
		-nln house \
		tmp/house.shp shp/state-districts/legislature/house-coastal-diff.shp
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		-update \
		-append \
		-nln house \
		tmp/house.shp shp/state-districts/legislature/house-non-coastal.shp

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/house.shp \
		-dialect sqlite \
		-sql "SELECT house.Geometry, \
				house.DISTRICT_I AS district \
			FROM house"

	@rm -rf tmp

exports/shp/state-districts/legislature/senate-fullsize.shp: \
	shp/state-districts/legislature/senate-crs.shp \
	exports/shp/water/lake-pontchartrain-fullsize.shp \
	exports/shp/water/gulf-of-mexico-fullsize.shp

	@mkdir -p $(dir $@)
	@mkdir -p tmp

	@# Remove Lake Pontchartrain
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="senate-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="lake-pontchartrain-fullsize">'\
				'<SrcDataSource>exports/shp/water/lake-pontchartrain-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/senate-no-lake.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(senate.GEOMETRY, lake.GEOMETRY) AS geometry, \
					senate.* \
				FROM 'senate-crs' AS senate, 'lake-pontchartrain-fullsize' AS lake"

	@# A-1.) Diffing only coastal precincts and Gulf of Mexico
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="senate-no-lake">'\
				'<SrcDataSource>tmp/senate-no-lake.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="gulf-of-mexico-fullsize">'\
				'<SrcDataSource>exports/shp/water/gulf-of-mexico-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/senate-coastal-diff.shp /vsistdin/ \
			-overwrite \
			-dialect sqlite \
			-sql "SELECT ST_Difference(senate.GEOMETRY, ST_Buffer(gulf.GEOMETRY, 0.0000001)) AS geometry, \
					senate.* \
				FROM 'senate-no-lake' as senate, 'gulf-of-mexico-fullsize' AS gulf \
				WHERE OBJECTID = '1' OR \
					OBJECTID = '8' OR \
					OBJECTID = '20' OR \
					OBJECTID = '21' OR \
					OBJECTID = '22' OR \
					OBJECTID = '25' OR \
					OBJECTID = '26'"
	@# A-2.) Removing coastal precincts from Louisiana precincts
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/senate-non-coastal.shp tmp/senate-no-lake.shp \
		-overwrite \
		-where 'OBJECTID != "1" AND \
				OBJECTID != "8" AND \
				OBJECTID != "20" AND \
				OBJECTID != "21" AND \
				OBJECTID != "22" AND \
				OBJECTID != "25" AND \
				OBJECTID != "26"'
	@# A-3.) Joining the two files (Louisiana precincts minus coastal precincts
	@# and the land-only portion of coastal precincts).
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/senate.shp tmp/senate-coastal-diff.shp \
		-update \
		-append \
		-nln senate
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/senate.shp tmp/senate-non-coastal.shp \
		-update \
		-append \
		-nln senate

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/senate.shp \
		-dialect sqlite \
		-sql "SELECT senate.Geometry, \
				senate.DISTRICT_I AS district \
			FROM senate"

	@rm -rf tmp

# Convert SHP to GeoJSON
exports/geojson/state-districts/legislature/%-fullsize.json: exports/shp/state-districts/legislature/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/state-districts/legislature/%-fullsize.json: exports/geojson/state-districts/legislature/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/state-districts/legislature/house-simplified.json: exports/topojson/state-districts/legislature/house-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-8 \
		-q 1e4 \
		-o $@ \
		-- $<

exports/topojson/state-districts/legislature/senate-simplified.json: exports/topojson/state-districts/legislature/senate-fullsize.json
	@mkdir -p $(dir $@)
	@rm -rf tmp
	@mkdir -p tmp
	@topojson \
		--spherical \
		--properties \
		-s 1e-8 \
		-q 1e4 \
		-o tmp/$(notdir $@) \
		-- $<

	@# A hack that smooths conversion of TopoJSON back to GeoJSON. Without
	@# Mapshaper, conversion fails on problematic InnerRing.
	@mapshaper \
		-i tmp/$(notdir $@) \
		-o $@

	@rm -rf tmp

# Convert simplified TopoJSON to simplified GeoJSON
exports/geojson/state-districts/legislature/%-simplified.json: exports/topojson/state-districts/legislature/%-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@

# Convert simplified GeoJSON to simplified shapefile
exports/shp/state-districts/legislature/%-simplified.shp: exports/geojson/state-districts/legislature/%-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<

legislature: \
	exports/shp/state-districts/legislature/house-simplified.shp \
	exports/shp/state-districts/legislature/senate-simplified.shp


#########################
#                       #
#  Municipal districts  #
#                       #
#########################

municipal-districts:
	@$(MAKE) opsb
	@$(MAKE) orleans-fqedd
	@$(MAKE) orleans-neighborhoods

###########################################
#  Orleans Parish School Board districts  #
###########################################

# Download OPSB .zip files
zip/municipal-districts/orleans/opsb/precinct-5-8-lakeside.zip:
	@# Hand-made file
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/hand-made/opsb/$(notdir $@)'
	@mv $@.download $@
zip/municipal-districts/orleans/opsb/precinct-5-8-riverside.zip:
	@# Hand-made file
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/hand-made/opsb/$(notdir $@)'
	@mv $@.download $@
zip/municipal-districts/orleans/opsb/precinct-7-12-lakeside.zip:
	@# Hand-made file
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/hand-made/opsb/$(notdir $@)'
	@mv $@.download $@
zip/municipal-districts/orleans/opsb/precinct-7-12-riverside.zip:
	@# Hand-made file
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/hand-made/opsb/$(notdir $@)'
	@mv $@.download $@

# Unzip data
shp/municipal-districts/orleans/opsb/precinct-5-8-lakeside.shp: zip/municipal-districts/orleans/opsb/precinct-5-8-lakeside.zip
	@mkdir -p $(dir $@)
	@unzip -q -o -d $(dir $@) $<
shp/municipal-districts/orleans/opsb/precinct-5-8-riverside.shp: zip/municipal-districts/orleans/opsb/precinct-5-8-riverside.zip
	@mkdir -p $(dir $@)
	@unzip -q -o -d $(dir $@) $<
shp/municipal-districts/orleans/opsb/precinct-7-12-lakeside.shp: zip/municipal-districts/orleans/opsb/precinct-7-12-lakeside.zip
	@mkdir -p $(dir $@)
	@unzip -q -o -d $(dir $@) $<
shp/municipal-districts/orleans/opsb/precinct-7-12-riverside.shp: zip/municipal-districts/orleans/opsb/precinct-7-12-riverside.zip
	@mkdir -p $(dir $@)
	@unzip -q -o -d $(dir $@) $<

shp/municipal-districts/orleans/opsb/opsb-district-1-precincts.shp: exports/shp/precincts/parish/orleans-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'PRECINCTID = "9-1" OR \
				PRECINCTID = "9-3" OR \
				PRECINCTID = "9-4" OR \
				PRECINCTID = "9-5" OR \
				PRECINCTID = "9-6" OR \
				PRECINCTID = "9-7" OR \
				PRECINCTID = "9-8" OR \
				PRECINCTID = "9-32" OR \
				PRECINCTID = "9-35" OR \
				PRECINCTID = "9-35A" OR \
				PRECINCTID = "9-36" OR \
				PRECINCTID = "9-36B" OR \
				PRECINCTID = "9-37" OR \
				PRECINCTID = "9-38" OR \
				PRECINCTID = "9-38A" OR \
				PRECINCTID = "9-39" OR \
				PRECINCTID = "9-39B" OR \
				PRECINCTID = "9-40" OR \
				PRECINCTID = "9-40A" OR \
				PRECINCTID = "9-40C" OR \
				PRECINCTID = "9-41" OR \
				PRECINCTID = "9-41A" OR \
				PRECINCTID = "9-41B" OR \
				PRECINCTID = "9-41C" OR \
				PRECINCTID = "9-41D" OR \
				PRECINCTID = "9-43H" OR \
				PRECINCTID = "9-43M" OR \
				PRECINCTID = "9-43N" OR \
				PRECINCTID = "9-44" OR \
				PRECINCTID = "9-44D" OR \
				PRECINCTID = "9-44E" OR \
				PRECINCTID = "9-44F" OR \
				PRECINCTID = "9-44G" OR \
				PRECINCTID = "9-44I" OR \
				PRECINCTID = "9-44J" OR \
				PRECINCTID = "9-44L" OR \
				PRECINCTID = "9-44M" OR \
				PRECINCTID = "9-44N" OR \
				PRECINCTID = "9-44O" OR \
				PRECINCTID = "9-44P" OR \
				PRECINCTID = "9-44Q" OR \
				PRECINCTID = "9-45" OR \
				PRECINCTID = "9-45A"'
	@ogrinfo $@ -sql "ALTER TABLE opsb-district-1-precincts ADD COLUMN DISTRICT varchar(1)"
	@ogrinfo $@ -dialect sqlite -sql "UPDATE 'opsb-district-1-precincts' SET DISTRICT = '1'"
shp/municipal-districts/orleans/opsb/opsb-district-1.shp: shp/municipal-districts/orleans/opsb/opsb-district-1-precincts.shp
	@# Buffer is to remove slivers that were forming inside the district shapes.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(ST_Buffer(GEOMETRY, 0.0000001)) AS geometry, \
				precincts.* \
			FROM 'opsb-district-1-precincts' AS precincts"

shp/municipal-districts/orleans/opsb/opsb-district-2-precincts.shp: exports/shp/precincts/parish/orleans-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'PRECINCTID = "8-4" OR \
				PRECINCTID = "8-6" OR \
				PRECINCTID = "8-7" OR \
				PRECINCTID = "8-8" OR \
				PRECINCTID = "8-9" OR \
				PRECINCTID = "8-12" OR \
				PRECINCTID = "8-13" OR \
				PRECINCTID = "8-14" OR \
				PRECINCTID = "8-15" OR \
				PRECINCTID = "8-19" OR \
				PRECINCTID = "8-20" OR \
				PRECINCTID = "8-21" OR \
				PRECINCTID = "8-22" OR \
				PRECINCTID = "8-23" OR \
				PRECINCTID = "8-24" OR \
				PRECINCTID = "8-30" OR \
				PRECINCTID = "9-10" OR \
				PRECINCTID = "9-17" OR \
				PRECINCTID = "9-19" OR \
				PRECINCTID = "9-21" OR \
				PRECINCTID = "9-23" OR \
				PRECINCTID = "9-25" OR \
				PRECINCTID = "9-26" OR \
				PRECINCTID = "9-28" OR \
				PRECINCTID = "9-28C" OR \
				PRECINCTID = "9-28E" OR \
				PRECINCTID = "9-29" OR \
				PRECINCTID = "9-30" OR \
				PRECINCTID = "9-30A" OR \
				PRECINCTID = "9-31" OR \
				PRECINCTID = "9-31A" OR \
				PRECINCTID = "9-31B" OR \
				PRECINCTID = "9-31D" OR \
				PRECINCTID = "9-33" OR \
				PRECINCTID = "9-34A" OR \
				PRECINCTID = "9-42" OR \
				PRECINCTID = "9-42C" OR \
				PRECINCTID = "9-43A" OR \
				PRECINCTID = "9-43B" OR \
				PRECINCTID = "9-43C" OR \
				PRECINCTID = "9-43E" OR \
				PRECINCTID = "9-43F" OR \
				PRECINCTID = "9-43G" OR \
				PRECINCTID = "9-43I" OR \
				PRECINCTID = "9-43J" OR \
				PRECINCTID = "9-43K" OR \
				PRECINCTID = "9-43L" OR \
				PRECINCTID = "9-44A" OR \
				PRECINCTID = "9-44B"'
	@ogrinfo \
		$@ \
		-sql "ALTER TABLE opsb-district-2-precincts ADD COLUMN DISTRICT varchar(1)"
	@ogrinfo \
		$@ \
		-dialect sqlite \
		-sql "UPDATE 'opsb-district-2-precincts' SET DISTRICT = '2'"
shp/municipal-districts/orleans/opsb/opsb-district-2.shp: shp/municipal-districts/orleans/opsb/opsb-district-2-precincts.shp
	@# Buffer is to remove slivers that were forming inside the district shapes.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(ST_Buffer(GEOMETRY, 0.0000001)) AS geometry, \
				precincts.* \
			FROM 'opsb-district-2-precincts' AS precincts"

shp/municipal-districts/orleans/opsb/opsb-district-3-precincts-untrimmed.shp: exports/shp/precincts/parish/orleans-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'PRECINCTID = "3-12" OR \
				PRECINCTID = "3-14" OR \
				PRECINCTID = "3-15" OR \
				PRECINCTID = "3-18" OR \
				PRECINCTID = "3-19" OR \
				PRECINCTID = "3-20" OR \
				PRECINCTID = "4-5" OR \
				PRECINCTID = "4-6" OR \
				PRECINCTID = "4-7" OR \
				PRECINCTID = "4-8" OR \
				PRECINCTID = "4-9" OR \
				PRECINCTID = "4-11" OR \
				PRECINCTID = "4-14" OR \
				PRECINCTID = "4-15" OR \
				PRECINCTID = "4-17" OR \
				PRECINCTID = "4-17A" OR \
				PRECINCTID = "4-18" OR \
				PRECINCTID = "4-20" OR \
				PRECINCTID = "4-21" OR \
				PRECINCTID = "4-22" OR \
				PRECINCTID = "4-23" OR \
				PRECINCTID = "5-8" OR \
				PRECINCTID = "5-9" OR \
				PRECINCTID = "5-10" OR \
				PRECINCTID = "5-11" OR \
				PRECINCTID = "5-12" OR \
				PRECINCTID = "5-13" OR \
				PRECINCTID = "5-15" OR \
				PRECINCTID = "5-16" OR \
				PRECINCTID = "5-17" OR \
				PRECINCTID = "5-18" OR \
				PRECINCTID = "6-9" OR \
				PRECINCTID = "7-12" OR \
				PRECINCTID = "7-17" OR \
				PRECINCTID = "7-18" OR \
				PRECINCTID = "7-19" OR \
				PRECINCTID = "7-30" OR \
				PRECINCTID = "7-32" OR \
				PRECINCTID = "7-33" OR \
				PRECINCTID = "7-34" OR \
				PRECINCTID = "7-35" OR \
				PRECINCTID = "7-37" OR \
				PRECINCTID = "7-37A" OR \
				PRECINCTID = "7-40" OR \
				PRECINCTID = "7-41" OR \
				PRECINCTID = "7-42" OR \
				PRECINCTID = "8-25" OR \
				PRECINCTID = "8-26" OR \
				PRECINCTID = "8-27" OR \
				PRECINCTID = "8-28" OR \
				PRECINCTID = "17-17" OR \
				PRECINCTID = "17-18" OR \
				PRECINCTID = "17-18A" OR \
				PRECINCTID = "17-19" OR \
				PRECINCTID = "17-20"'

shp/municipal-districts/orleans/opsb/opsb-district-3-precincts.shp: \
	shp/municipal-districts/orleans/opsb/opsb-district-3-precincts-untrimmed.shp \
	shp/municipal-districts/orleans/opsb/precinct-5-8-riverside.shp \
	shp/municipal-districts/orleans/opsb/precinct-7-12-riverside.shp
	@# Remove portion of precincts 5-8 and 7-12. OPSB district doesn't perfectly align with precinct.
	@mkdir -p $(dir $@)
	@mkdir -p tmp
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="opsb-district-3-precincts-untrimmed">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="precinct-5-8-riverside">'\
				'<SrcDataSource>shp/municipal-districts/orleans/opsb/precinct-5-8-riverside.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/dist-3-minus-5-8.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(district.GEOMETRY, precinct.GEOMETRY) AS geometry, \
					district.* \
				FROM 'opsb-district-3-precincts-untrimmed' AS district, 'precinct-5-8-riverside' AS precinct"
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="dist-3-minus-5-8">'\
				'<SrcDataSource>tmp/dist-3-minus-5-8.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="precinct-7-12-riverside">'\
				'<SrcDataSource>shp/municipal-districts/orleans/opsb/precinct-7-12-riverside.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(district.GEOMETRY, precinct.GEOMETRY) AS geometry, \
					district.* \
				FROM 'dist-3-minus-5-8' AS district, 'precinct-7-12-riverside' AS precinct"

	@ogrinfo \
		$@ \
		-sql "ALTER TABLE opsb-district-3-precincts ADD COLUMN DISTRICT varchar(1)"
	@ogrinfo \
		$@ \
		-dialect sqlite \
		-sql "UPDATE 'opsb-district-3-precincts' SET DISTRICT = '3'"

	@rm -rf tmp
shp/municipal-districts/orleans/opsb/opsb-district-3.shp: shp/municipal-districts/orleans/opsb/opsb-district-3-precincts.shp
	@# Buffer is to remove slivers that were forming inside the district shapes.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(ST_Buffer(GEOMETRY, 0.0000001)) AS geometry, \
				precincts.* \
			FROM 'opsb-district-3-precincts' AS precincts"

shp/municipal-districts/orleans/opsb/opsb-district-4-precincts.shp: exports/shp/precincts/parish/orleans-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'PRECINCTID = "5-1" OR \
				PRECINCTID = "6-1" OR \
				PRECINCTID = "8-1" OR \
				PRECINCTID = "8-2" OR \
				PRECINCTID = "9-9" OR \
				PRECINCTID = "9-11" OR \
				PRECINCTID = "9-12" OR \
				PRECINCTID = "9-13" OR \
				PRECINCTID = "9-14" OR \
				PRECINCTID = "9-15" OR \
				PRECINCTID = "9-16" OR \
				PRECINCTID = "15-1" OR \
				PRECINCTID = "15-2" OR \
				PRECINCTID = "15-3" OR \
				PRECINCTID = "15-9" OR \
				PRECINCTID = "15-12" OR \
				PRECINCTID = "15-13" OR \
				PRECINCTID = "15-14" OR \
				PRECINCTID = "15-14A" OR \
				PRECINCTID = "15-14B" OR \
				PRECINCTID = "15-14C" OR \
				PRECINCTID = "15-14D" OR \
				PRECINCTID = "15-14E" OR \
				PRECINCTID = "15-14F" OR \
				PRECINCTID = "15-14G" OR \
				PRECINCTID = "15-15" OR \
				PRECINCTID = "15-15A" OR \
				PRECINCTID = "15-15B" OR \
				PRECINCTID = "15-16" OR \
				PRECINCTID = "15-17" OR \
				PRECINCTID = "15-17A" OR \
				PRECINCTID = "15-17B" OR \
				PRECINCTID = "15-18" OR \
				PRECINCTID = "15-18A" OR \
				PRECINCTID = "15-18B" OR \
				PRECINCTID = "15-18C" OR \
				PRECINCTID = "15-18D" OR \
				PRECINCTID = "15-18E" OR \
				PRECINCTID = "15-18F" OR \
				PRECINCTID = "15-19" OR \
				PRECINCTID = "15-19A" OR \
				PRECINCTID = "15-19B" OR \
				PRECINCTID = "15-19C"'
	@ogrinfo \
		$@ \
		-sql "ALTER TABLE opsb-district-4-precincts ADD COLUMN DISTRICT varchar(1)"
	@ogrinfo \
		$@ \
		-dialect sqlite \
		-sql "UPDATE 'opsb-district-4-precincts' SET DISTRICT = '4'"
shp/municipal-districts/orleans/opsb/opsb-district-4.shp: shp/municipal-districts/orleans/opsb/opsb-district-4-precincts.shp
	@# Buffer is to remove slivers that were forming inside the district shapes.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(ST_Buffer(GEOMETRY, 0.0000001)) AS geometry, \
				precincts.* \
			FROM 'opsb-district-4-precincts' AS precincts"

shp/municipal-districts/orleans/opsb/opsb-district-5-precincts.shp: exports/shp/precincts/parish/orleans-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'PRECINCTID = "1-1" OR \
				PRECINCTID = "1-2" OR \
				PRECINCTID = "1-5" OR \
				PRECINCTID = "1-6" OR \
				PRECINCTID = "2-1" OR \
				PRECINCTID = "2-2" OR \
				PRECINCTID = "10-3" OR \
				PRECINCTID = "10-6" OR \
				PRECINCTID = "10-7" OR \
				PRECINCTID = "10-8" OR \
				PRECINCTID = "10-9" OR \
				PRECINCTID = "10-11" OR \
				PRECINCTID = "10-12" OR \
				PRECINCTID = "10-13" OR \
				PRECINCTID = "10-14" OR \
				PRECINCTID = "11-2" OR \
				PRECINCTID = "11-3" OR \
				PRECINCTID = "11-4" OR \
				PRECINCTID = "11-5" OR \
				PRECINCTID = "11-8" OR \
				PRECINCTID = "11-9" OR \
				PRECINCTID = "11-10" OR \
				PRECINCTID = "11-11" OR \
				PRECINCTID = "11-12" OR \
				PRECINCTID = "11-13" OR \
				PRECINCTID = "11-14" OR \
				PRECINCTID = "12-1" OR \
				PRECINCTID = "12-2" OR \
				PRECINCTID = "12-3" OR \
				PRECINCTID = "12-4" OR \
				PRECINCTID = "12-5" OR \
				PRECINCTID = "12-6" OR \
				PRECINCTID = "12-7" OR \
				PRECINCTID = "12-8" OR \
				PRECINCTID = "12-9" OR \
				PRECINCTID = "12-10" OR \
				PRECINCTID = "12-11" OR \
				PRECINCTID = "12-12" OR \
				PRECINCTID = "12-13" OR \
				PRECINCTID = "12-14" OR \
				PRECINCTID = "12-16" OR \
				PRECINCTID = "12-17" OR \
				PRECINCTID = "13-1" OR \
				PRECINCTID = "13-2" OR \
				PRECINCTID = "13-3" OR \
				PRECINCTID = "13-4" OR \
				PRECINCTID = "13-5" OR \
				PRECINCTID = "13-6" OR \
				PRECINCTID = "13-7" OR \
				PRECINCTID = "13-9" OR \
				PRECINCTID = "13-10" OR \
				PRECINCTID = "13-11" OR \
				PRECINCTID = "13-12" OR \
				PRECINCTID = "13-13" OR \
				PRECINCTID = "13-14" OR \
				PRECINCTID = "13-15" OR \
				PRECINCTID = "13-16" OR \
				PRECINCTID = "14-15" OR \
				PRECINCTID = "14-20" OR \
				PRECINCTID = "14-23"'
	@ogrinfo \
		$@ \
		-sql "ALTER TABLE opsb-district-5-precincts ADD COLUMN DISTRICT varchar(1)"
	@ogrinfo \
		$@ \
		-dialect sqlite \
		-sql "UPDATE 'opsb-district-5-precincts' SET DISTRICT = '5'"
shp/municipal-districts/orleans/opsb/opsb-district-5.shp: shp/municipal-districts/orleans/opsb/opsb-district-5-precincts.shp
	@# Buffer is to remove slivers that were forming inside the district shapes.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(ST_Buffer(GEOMETRY, 0.0000001)) AS geometry, \
				precincts.* \
			FROM 'opsb-district-5-precincts' AS precincts"

shp/municipal-districts/orleans/opsb/opsb-district-6-precincts.shp: exports/shp/precincts/parish/orleans-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'PRECINCTID = "2-4" OR \
				PRECINCTID = "2-6" OR \
				PRECINCTID = "2-6A" OR \
				PRECINCTID = "2-7" OR \
				PRECINCTID = "11-17" OR \
				PRECINCTID = "12-19" OR \
				PRECINCTID = "13-8" OR \
				PRECINCTID = "14-1" OR \
				PRECINCTID = "14-2" OR \
				PRECINCTID = "14-3" OR \
				PRECINCTID = "14-4" OR \
				PRECINCTID = "14-5" OR \
				PRECINCTID = "14-6" OR \
				PRECINCTID = "14-7" OR \
				PRECINCTID = "14-8" OR \
				PRECINCTID = "14-9" OR \
				PRECINCTID = "14-10" OR \
				PRECINCTID = "14-11" OR \
				PRECINCTID = "14-12" OR \
				PRECINCTID = "14-13A" OR \
				PRECINCTID = "14-14" OR \
				PRECINCTID = "14-16" OR \
				PRECINCTID = "14-17" OR \
				PRECINCTID = "14-18A" OR \
				PRECINCTID = "14-19" OR \
				PRECINCTID = "14-21" OR \
				PRECINCTID = "14-24A" OR \
				PRECINCTID = "14-25" OR \
				PRECINCTID = "14-26" OR \
				PRECINCTID = "16-1" OR \
				PRECINCTID = "16-1A" OR \
				PRECINCTID = "16-2" OR \
				PRECINCTID = "16-3" OR \
				PRECINCTID = "16-4" OR \
				PRECINCTID = "16-5" OR \
				PRECINCTID = "16-6" OR \
				PRECINCTID = "16-7" OR \
				PRECINCTID = "16-8" OR \
				PRECINCTID = "16-9" OR \
				PRECINCTID = "17-1" OR \
				PRECINCTID = "17-2" OR \
				PRECINCTID = "17-3" OR \
				PRECINCTID = "17-4" OR \
				PRECINCTID = "17-5" OR \
				PRECINCTID = "17-6" OR \
				PRECINCTID = "17-7" OR \
				PRECINCTID = "17-8" OR \
				PRECINCTID = "17-9" OR \
				PRECINCTID = "17-10" OR \
				PRECINCTID = "17-11" OR \
				PRECINCTID = "17-12" OR \
				PRECINCTID = "17-13" OR \
				PRECINCTID = "17-13A" OR \
				PRECINCTID = "17-14" OR \
				PRECINCTID = "17-15" OR \
				PRECINCTID = "17-16"'
	@ogrinfo \
		$@ \
		-sql "ALTER TABLE opsb-district-6-precincts ADD COLUMN DISTRICT varchar(1)"
	@ogrinfo \
		$@ \
		-dialect sqlite \
		-sql "UPDATE 'opsb-district-6-precincts' SET DISTRICT = '6'"
shp/municipal-districts/orleans/opsb/opsb-district-6.shp: shp/municipal-districts/orleans/opsb/opsb-district-6-precincts.shp
	@# Buffer is to remove slivers that were forming inside the district shapes.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(ST_Buffer(GEOMETRY, 0.0000001)) AS geometry, \
				precincts.* \
			FROM 'opsb-district-6-precincts' AS precincts"

shp/municipal-districts/orleans/opsb/opsb-district-7-precincts-untrimmed.shp: exports/shp/precincts/parish/orleans-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'PRECINCTID = "3-1" OR \
				PRECINCTID = "3-3" OR \
				PRECINCTID = "3-5" OR \
				PRECINCTID = "3-8" OR \
				PRECINCTID = "3-9" OR \
				PRECINCTID = "4-2" OR \
				PRECINCTID = "4-3" OR \
				PRECINCTID = "4-4" OR \
				PRECINCTID = "5-2" OR \
				PRECINCTID = "5-3" OR \
				PRECINCTID = "5-4" OR \
				PRECINCTID = "5-5" OR \
				PRECINCTID = "5-7" OR \
				PRECINCTID = "5-8" OR \
				PRECINCTID = "6-2" OR \
				PRECINCTID = "6-4" OR \
				PRECINCTID = "6-6" OR \
				PRECINCTID = "6-7" OR \
				PRECINCTID = "6-8" OR \
				PRECINCTID = "7-1" OR \
				PRECINCTID = "7-2" OR \
				PRECINCTID = "7-4" OR \
				PRECINCTID = "7-5" OR \
				PRECINCTID = "7-6" OR \
				PRECINCTID = "7-7" OR \
				PRECINCTID = "7-8" OR \
				PRECINCTID = "7-9A" OR \
				PRECINCTID = "7-10" OR \
				PRECINCTID = "7-11" OR \
				PRECINCTID = "7-12" OR \
				PRECINCTID = "7-13" OR \
				PRECINCTID = "7-14" OR \
				PRECINCTID = "7-15" OR \
				PRECINCTID = "7-16" OR \
				PRECINCTID = "7-20" OR \
				PRECINCTID = "7-21" OR \
				PRECINCTID = "7-23" OR \
				PRECINCTID = "7-24" OR \
				PRECINCTID = "7-25" OR \
				PRECINCTID = "7-25A" OR \
				PRECINCTID = "7-26" OR \
				PRECINCTID = "7-27" OR \
				PRECINCTID = "7-27B" OR \
				PRECINCTID = "7-28" OR \
				PRECINCTID = "7-28A" OR \
				PRECINCTID = "7-29" OR \
				PRECINCTID = "15-5" OR \
				PRECINCTID = "15-6" OR \
				PRECINCTID = "15-8" OR \
				PRECINCTID = "15-10" OR \
				PRECINCTID = "15-11" OR \
				PRECINCTID = "15-12A" OR \
				PRECINCTID = "15-13A" OR \
				PRECINCTID = "15-13B"'
shp/municipal-districts/orleans/opsb/opsb-district-7-precincts.shp: \
	shp/municipal-districts/orleans/opsb/opsb-district-7-precincts-untrimmed.shp \
	shp/municipal-districts/orleans/opsb/precinct-5-8-lakeside.shp \
	shp/municipal-districts/orleans/opsb/precinct-7-12-lakeside.shp

	@# Remove portion of precincts 5-8 and 7-12. OPSB district doesn't perfectly align with precinct.
	@mkdir -p $(dir $@)
	@mkdir -p tmp
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="opsb-district-7-precincts-untrimmed">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="precinct-5-8-lakeside">'\
				'<SrcDataSource>shp/municipal-districts/orleans/opsb/precinct-5-8-lakeside.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/opsb-district-7-precinct-5-8.shp /vsistdin/ \
			-overwrite \
			-dialect sqlite \
			-sql "SELECT ST_Difference(district.GEOMETRY, precinct.GEOMETRY) AS geometry, \
					district.* \
				FROM 'opsb-district-7-precincts-untrimmed' AS district, 'precinct-5-8-lakeside' AS precinct"
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="opsb-district-7-precinct-5-8">'\
				'<SrcDataSource>tmp/opsb-district-7-precinct-5-8.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="precinct-7-12-lakeside">'\
				'<SrcDataSource>shp/municipal-districts/orleans/opsb/precinct-7-12-lakeside.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-overwrite \
			-dialect sqlite \
			-sql "SELECT ST_Difference(district.GEOMETRY, precinct.GEOMETRY) AS geometry, district.* FROM 'opsb-district-7-precinct-5-8' AS district, 'precinct-7-12-lakeside' AS precinct"

	@ogrinfo \
		$@ \
		-sql "ALTER TABLE opsb-district-7-precincts ADD COLUMN DISTRICT varchar(1)"
	@ogrinfo \
		$@ \
		-dialect sqlite \
		-sql "UPDATE 'opsb-district-7-precincts' SET DISTRICT = '7'"

	@rm -rf tmp
shp/municipal-districts/orleans/opsb/opsb-district-7.shp: shp/municipal-districts/orleans/opsb/opsb-district-7-precincts.shp
	@# Buffer is to remove slivers that were forming inside the district shapes.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(ST_Buffer(GEOMETRY, 0.0000001)) AS geometry, \
				precincts.* \
			FROM 'opsb-district-7-precincts' AS precincts"

exports/shp/municipal-districts/orleans/opsb/opsb-fullsize.shp: \
	shp/municipal-districts/orleans/opsb/opsb-district-1.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-2.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-3.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-4.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-5.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-6.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-7.shp

	@mkdir -p $(dir $@)
	@mkdir -p tmp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln opsb \
			tmp/opsb.shp $$file; \
	done

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/opsb.shp \
		-dialect sqlite \
		-sql "SELECT Geometry, \
				precinctid, \
				parishname, \
				DISTRICT AS district \
			FROM opsb"

	@rm -rf tmp

exports/shp/municipal-districts/orleans/opsb/opsb-precincts-fullsize.shp: \
	shp/municipal-districts/orleans/opsb/opsb-district-1-precincts.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-2-precincts.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-3-precincts.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-4-precincts.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-5-precincts.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-6-precincts.shp \
	shp/municipal-districts/orleans/opsb/opsb-district-7-precincts.shp

	@mkdir -p $(dir $@)
	@mkdir -p tmp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln 'opsb-precincts' \
			tmp/opsb-precincts.shp $$file; \
	done

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/opsb-precincts.shp \
		-dialect sqlite \
		-sql "SELECT Geometry, \
				precinctid, \
				parishname, \
				DISTRICT AS district \
			FROM 'opsb-precincts'"

	@rm -rf tmp

# Convert SHP to GeoJSON
exports/geojson/municipal-districts/orleans/opsb/opsb-fullsize.json: exports/shp/municipal-districts/orleans/opsb/opsb-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<
exports/geojson/municipal-districts/orleans/opsb/opsb-precincts-fullsize.json: exports/shp/municipal-districts/orleans/opsb/opsb-precincts-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/municipal-districts/orleans/opsb/opsb-fullsize.json: exports/geojson/municipal-districts/orleans/opsb/opsb-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<
exports/topojson/municipal-districts/orleans/opsb/opsb-precincts-fullsize.json: exports/geojson/municipal-districts/orleans/opsb/opsb-precincts-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/municipal-districts/orleans/opsb/opsb-simplified.json: exports/topojson/municipal-districts/orleans/opsb/opsb-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 3e-12 \
		-q 1e6 \
		-o $@ \
		-- $<
exports/topojson/municipal-districts/orleans/opsb/opsb-precincts-simplified.json: exports/topojson/municipal-districts/orleans/opsb/opsb-precincts-fullsize.json

	@mkdir -p $(dir $@)
	@rm -rf tmp && mkdir -p tmp
	@topojson \
		--spherical \
		--properties \
		-s 3e-12 \
		-q 1e6 \
		-o tmp/$(notdir $@) \
		-- $<

	@# A hack that smooths conversion of TopoJSON back to GeoJSON. Without
	@# Mapshaper, conversion fails with
	@# AttributeError: 'NoneType' object has no attribute 'coords'
	@mapshaper \
		-i tmp/$(notdir $@) \
		-o $@

	@rm -rf tmp

# Convert simplified TopoJSON to simplified GeoJSON
exports/geojson/municipal-districts/orleans/opsb/opsb-simplified.json: exports/topojson/municipal-districts/orleans/opsb/opsb-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@
exports/geojson/municipal-districts/orleans/opsb/opsb-precincts-simplified.json: exports/topojson/municipal-districts/orleans/opsb/opsb-precincts-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@

# Convert simplified GeoJSON to simplified shapefile
exports/shp/municipal-districts/orleans/opsb/opsb-simplified.shp: exports/geojson/municipal-districts/orleans/opsb/opsb-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<
exports/shp/municipal-districts/orleans/opsb/opsb-precincts-simplified.shp: exports/geojson/municipal-districts/orleans/opsb/opsb-precincts-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<

opsb: \
	exports/shp/municipal-districts/orleans/opsb/opsb-simplified.shp \
	exports/shp/municipal-districts/orleans/opsb/opsb-precincts-simplified.shp

##################################################
#  French Quarter Economic Development District  #
##################################################

# Learn more: http://nola.gov/fqedd/
# Boundaries are center line of Canal Street, Mississippi River, back property line
# of properties along Rampart Street facing river, and back property line of
# properties along Esplanade Avenue facing Uptown.

# Download New Orleans neighborhoods .zip file
zip/municipal-districts/orleans/economic/%.zip:
	@mkdir -p $(dir $@)
	@# Hand-made file
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/hand-made/french-quarter-economic-development-district/fq-econ-dev-dist.zip'
	@mv $@.download $@

# Unzip
shp/municipal-districts/orleans/economic/%-extracted.shp: zip/municipal-districts/orleans/economic/%.zip
	@mkdir -p $(dir $@)

	@# Extract .zip contents to temporary folder
	@mkdir -p tmp
	@unzip -q -o -d tmp $<

	@# Renaming .zip contents in case they have a space in their names.
	@# Note that this is problematic if there are multiple files with the same file extension.
	@for file in tmp/*.*; do \
		fullfile=$$(basename "$$file") && \
		filename=$${fullfile%.*} && \
		fileextension="$${file##*.}" && \
		cp "$$file" "$(dir $@)$*-extracted.$$fileextension" ; \
	done

	@rm -rf tmp

shp/municipal-districts/orleans/economic/%-crs.shp: shp/municipal-districts/orleans/economic/%-extracted.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs "EPSG:4326"

exports/shp/municipal-districts/orleans/economic/%-fullsize.shp: shp/municipal-districts/orleans/economic/%-crs.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT district.GEOMETRY AS geometry, \
				district.* \
			FROM 'french-quarter-econ-dev-dist-crs' AS district"

# Convert SHP to GeoJSON
exports/geojson/municipal-districts/orleans/economic/%-fullsize.json: exports/shp/municipal-districts/orleans/economic/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/municipal-districts/orleans/economic/%-fullsize.json: exports/geojson/municipal-districts/orleans/economic/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/municipal-districts/orleans/economic/%-simplified.json: exports/topojson/municipal-districts/orleans/economic/%-fullsize.json
	@mkdir -p $(dir $@)
	@# Don't bother simplifying geography since file is so small.
	@topojson \
		--simplify-proportion 0.999999999 \
		--properties \
		-o $@ \
		-- $<

orleans-fqedd: exports/topojson/municipal-districts/orleans/economic/french-quarter-econ-dev-dist-simplified.json


###################
#  Neighborhoods  #
###################

# Download New Orleans neighborhoods .zip file
zip/municipal-districts/orleans/neighborhoods/new-orleans.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://data.nola.gov/api/geospatial/ukvx-5dku?method=export&format=Shapefile'
	@mv $@.download $@

# Unzip
shp/municipal-districts/orleans/neighborhoods/%-extracted.shp: zip/municipal-districts/orleans/neighborhoods/%.zip
	@mkdir -p $(dir $@)

	@# Extract .zip contents to temporary folder
	@mkdir -p tmp
	@unzip -q -o -d tmp $<

	@# Renaming .zip contents in case they have a space in their names.
	@# Note that this is problematic if there are multiple files with the same file extension.
	@for file in tmp/*.*; do \
		fullfile=$$(basename "$$file") && \
		filename=$${fullfile%.*} && \
		fileextension="$${file##*.}" && \
		cp "$$file" "$(dir $@)$*-extracted.$$fileextension" ; \
	done

	@rm -rf tmp

# Change coordinate system to WGS 84 (EPSG:4326)
shp/municipal-districts/orleans/neighborhoods/%-crs.shp: shp/municipal-districts/orleans/neighborhoods/%-extracted.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs "EPSG:4326"

# Remove Mississippi River. Lake Pontchartrain already absent.
# May want to keep OBJECTID and NEIGH_ID for certain cases.
exports/shp/municipal-districts/orleans/neighborhoods/new-orleans-fullsize.shp: \
	shp/municipal-districts/orleans/neighborhoods/new-orleans-crs.shp \
	exports/shp/water/mississippi-river-fullsize.shp

	@# Remove Mississippi River.
	@mkdir -p $(dir $@)
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="new-orleans-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="mississippi-river-fullsize">'\
				'<SrcDataSource>exports/shp/water/mississippi-river-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(neighborhoods.GEOMETRY, river.GEOMETRY) AS geometry, \
					neighborhoods.GNOCDC_LAB AS nbhd_name \
				FROM 'new-orleans-crs' AS neighborhoods, 'mississippi-river-fullsize' AS river"

# Convert SHP to GeoJSON
exports/geojson/municipal-districts/orleans/neighborhoods/%-fullsize.json: exports/shp/municipal-districts/orleans/neighborhoods/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/municipal-districts/orleans/neighborhoods/%-fullsize.json: exports/geojson/municipal-districts/orleans/neighborhoods/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/municipal-districts/orleans/neighborhoods/%-simplified.json: exports/topojson/municipal-districts/orleans/neighborhoods/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-12 \
		-q 1e8 \
		-o $@ \
		-- $<

# Convert simplified TopoJSON to simplified GeoJSON
exports/geojson/municipal-districts/orleans/neighborhoods/%-simplified.json: exports/topojson/municipal-districts/orleans/neighborhoods/%-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@

# Convert simplified GeoJSON to simplified shapefile
exports/shp/municipal-districts/orleans/neighborhoods/%-simplified.shp: exports/geojson/municipal-districts/orleans/neighborhoods/%-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<

orleans-neighborhoods: \
	exports/shp/municipal-districts/orleans/neighborhoods/new-orleans-simplified.shp


##############
#            #
#  Parishes  #
#            #
##############

# Download parishes .zip file
zip/parishes/tl_2010_22_county10.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'ftp://ftp2.census.gov/geo/pvs/tiger2010st/22_Louisiana/22/$(notdir $@)'
	@mv $@.download $@

# Unzip
shp/parishes/tl_2010_22_county10.shp: zip/parishes/tl_2010_22_county10.zip
	@mkdir -p $(dir $@)
	@unzip -q -o -d $(dir $@) $<

# Fix CRS
shp/parishes/parishes-crs.shp: shp/parishes/tl_2010_22_county10.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs "EPSG:4326"

# Remove water features
# Louisiana: Remove Gulf of Mexico coastline
exports/shp/parishes/parishes-fullsize.shp: shp/parishes/parishes-crs.shp \
	exports/shp/water/gulf-of-mexico-fullsize.shp

	@mkdir -p $(dir $@)

	@# Remove Gulf of Mexico
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="parishes-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="gulf-of-mexico-fullsize">'\
				'<SrcDataSource>exports/shp/water/gulf-of-mexico-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(parishes.GEOMETRY, gulf.GEOMETRY) AS geometry, \
					parishes.COUNTYFP10 AS parishcode, \
					parishes.NAME10 AS parishname \
				FROM 'parishes-crs' AS parishes, 'gulf-of-mexico-fullsize' AS gulf"

# Convert SHP to GeoJSON
exports/geojson/parishes/%-fullsize.json: exports/shp/parishes/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/parishes/%-fullsize.json: exports/geojson/parishes/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/parishes/%-simplified.json: exports/topojson/parishes/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 3e-8 \
		-q 1e4 \
		-o $@ \
		-- $<

# Convert simplified TopoJSON to simplified GeoJSON
exports/geojson/parishes/%-simplified.json: exports/topojson/parishes/%-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@

# Convert simplified GeoJSON to simplified shapefile
exports/shp/parishes/%-simplified.shp: exports/geojson/parishes/%-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<

exports/shp/parishes/parishes-no-islands-fullsize.shp: exports/shp/parishes/parishes-fullsize.shp
	@mkdir -p $(dir $@)
	@rm -rf tmp && mkdir -p tmp

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/noislands.shp $<

	@dropdb --if-exists temp_db
	@createdb temp_db
	@psql temp_db -c "CREATE EXTENSION postgis;"
	@shp2pgsql -s 4326 tmp/noislands noislands | psql -d temp_db
	@psql temp_db -c "CREATE INDEX noislands_index ON noislands USING GIST (geom);"

	@psql temp_db -c "DROP TABLE IF EXISTS singleparts;"
	@psql temp_db -c "CREATE TABLE singleparts AS \
		SELECT parishname, \
			parishcode, \
			(ST_Dump(geom)).geom AS singleparts_geom \
		FROM noislands;"

	@psql temp_db -c "CREATE INDEX singleparts_index ON singleparts USING GIST (singleparts_geom);"
	@psql temp_db -c "ALTER TABLE singleparts ADD COLUMN sqft double precision;"
	@psql temp_db -c "ALTER TABLE singleparts ADD COLUMN sqmi double precision;"
	@psql temp_db -c "UPDATE singleparts \
		SET sqft = ST_Area(singleparts_geom);"
	@psql temp_db -c "UPDATE singleparts \
		SET sqmi = ST_Area(singleparts_geom)*POWER(0.3048,2);"

	@pgsql2shp -f tmp/noislands.shp temp_db "SELECT * \
		FROM singleparts WHERE sqmi > 0.0000056;"

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/noislands.shp \
		-dialect sqlite \
		-sql "SELECT DISTINCT PARISHCODE AS parishcode, \
				PARISHNAME AS parishname, \
				St_Union(GEOMETRY) AS geometry \
			FROM noislands \
			GROUP BY parishcode"

	@dropdb temp_db
	@rm -rf tmp

parishes: exports/shp/parishes/parishes-simplified.shp \
	exports/shp/parishes/parishes-no-islands-simplified.shp


###############
#             #
#  Precincts  #
#             #
###############

# Download Louisiana precincts shapefile. NOTE: These are almost always outdated!
zip/precincts/louisiana.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'http://house.louisiana.gov/H_Redistricting2011/Shapefiles/2014_LouisianaPrecinctShapefile.ZIP'
	@mv $@.download $@

zip/precincts/caddo.zip:
	@# From a public records request.
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/hand-made/precincts/caddo-hand-adjusted.zip'
	@mv $@.download $@
zip/precincts/jefferson.zip:
	@# From a public records request
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/hand-made/precincts/jefferson-parish-precincts.zip'
	@mv $@.download $@
zip/precincts/lafayette.zip:
	@# From a public records request
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/public-records-requests/lafayette-precincts.zip'
	@mv $@.download $@
zip/precincts/orleans.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://data.nola.gov/api/geospatial/vycb-i8x3?method=export&format=Shapefile'
	@mv $@.download $@
zip/precincts/st-tammany.zip:
	@# From a public records request. Hand-adjusted to delete stray polygon
	@# on precinct 815.
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://s3-us-west-2.amazonaws.com/projects.thelensnola.org/geographic-data/hand-made/precincts/st-tammany-hand-adjusted.zip'
	@mv $@.download $@

# Download East Baton Rouge as JSON and convert to SHP for processing.
tmp/precincts/east-baton-rouge.json:
	@mkdir -p $(dir $@)
	@python scripts/download_east_baton_rouge_precincts.py $@
shp/precincts/east-baton-rouge-crs.shp: tmp/precincts/east-baton-rouge.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs "EPSG:4326"

# Unzip downloaded .zip files.
shp/precincts/%-extracted.shp: zip/precincts/%.zip
	@mkdir -p $(dir $@)

	@# Extract .zip contents to temporary folder
	@mkdir -p tmp
	@unzip -q -o -d tmp $<

	@for file in tmp/*.*; do \
		fullfile=$$(basename "$$file") && \
		filename=$${fullfile%.*} && \
		fileextension="$${file##*.}" && \
		cp "$$file" "$(dir $@)$*-extracted.$$fileextension" ; \
	done

	@rm -rf tmp

# Converting coordinate reference systems to WGS 84 (EPSG:4326).
# Louisiana comes with CRS of GCS North American Datum 1983 (NAD83).
# New Orleans comes with CRS of NAD_1983_StatePlane_Louisiana_South_FIPS_1702_Feet.
shp/precincts/%-crs.shp: shp/precincts/%-extracted.shp
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		-t_srs "EPSG:4326" \
		$@ $<

# Remove water geometry.
# Louisiana precincts.
exports/shp/precincts/state/louisiana-fullsize.shp: shp/precincts/louisiana-crs.shp \
	exports/shp/water/gulf-of-mexico-fullsize.shp

	@mkdir -p $(dir $@)
	@mkdir -p tmp

	@# A. This method takes about 20 minutes.
	@# A-1.) Diffing only coastal precincts and Gulf of Mexico
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="louisiana-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="gulf-of-mexico-fullsize">'\
				'<SrcDataSource>exports/shp/water/gulf-of-mexico-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/coastal-diff.shp /vsistdin/ \
			-overwrite \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, ST_Buffer(gulf.GEOMETRY, 0.00075)) AS geometry, \
					precincts.* \
				FROM 'louisiana-crs' as precincts, 'gulf-of-mexico-fullsize' AS gulf \
				WHERE OBJECTID = '629' OR \
					OBJECTID = '634' OR \
					OBJECTID = '639' OR \
					OBJECTID = '15226' OR \
					OBJECTID = '3371' OR \
					OBJECTID = '3396' OR \
					OBJECTID = '3399' OR \
					OBJECTID = '1156' OR \
					OBJECTID = '2962' OR \
					OBJECTID = '2990' OR \
					OBJECTID = '8473' OR \
					OBJECTID = '3333' OR \
					OBJECTID = '3316' OR \
					OBJECTID = '13924' OR \
					OBJECTID = '3267' OR \
					OBJECTID = '3322' OR \
					OBJECTID = '1675' OR \
					OBJECTID = '1655' OR \
					OBJECTID = '1359' OR \
					OBJECTID = '1368' OR \
					OBJECTID = '16177' OR \
					OBJECTID = '16179' OR \
					OBJECTID = '16181' OR \
					OBJECTID = '16180' OR \
					OBJECTID = '2447' OR \
					OBJECTID = '2676' OR \
					OBJECTID = '3143'"
	@# A-2.) Removing coastal precincts from Louisiana precincts
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/non-coastal.shp $< \
		-overwrite \
		-where "OBJECTID != '629' AND \
				OBJECTID != '634' AND \
				OBJECTID != '639' AND \
				OBJECTID != '15226' AND \
				OBJECTID != '3371' AND \
				OBJECTID != '3396' AND \
				OBJECTID != '1156' AND \
				OBJECTID != '2990' AND \
				OBJECTID != '8473' AND \
				OBJECTID != '3333' AND \
				OBJECTID != '13924' AND \
				OBJECTID != '1655' AND \
				OBJECTID != '1368' AND \
				OBJECTID != '16177' AND \
				OBJECTID != '16179' AND \
				OBJECTID != '16181' AND \
				OBJECTID != '16180' AND \
				OBJECTID != '2447' AND \
				OBJECTID != '2676' AND \
				OBJECTID != '3143'"
	@# A-3.) Joining the two files (Louisiana precincts minus coastal precincts
	@# and the land-only portion of coastal precincts).
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		-update \
		-append \
		-nln louisiana \
		tmp/louisiana.shp tmp/coastal-diff.shp
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		-update \
		-append \
		-nln louisiana \
		tmp/louisiana.shp tmp/non-coastal.shp

	@# JOIN the FIPS codes and names by using CSV with codes + parish names.
	@dropdb --if-exists temp_db
	@createdb temp_db
	@psql temp_db -c "CREATE EXTENSION postgis;"
	@shp2pgsql -s 4326 tmp/louisiana louisiana | psql -d temp_db
	@psql temp_db -c "CREATE TABLE fipslink (FIPS varchar(3), name varchar(50));"
	@psql temp_db -c "COPY fipslink (FIPS, name) \
		FROM '$(shell pwd)/data/fips-codes.csv' DELIMITER ',' CSV HEADER;"
	@pgsql2shp -f tmp/louisiana.shp temp_db "SELECT louisiana.*, \
			fipslink.name \
		FROM louisiana \
		JOIN fipslink ON louisiana.countyfp10 = fipslink.fips;"
	@dropdb temp_db

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/louisiana.shp \
		-dialect sqlite \
		-sql "SELECT louisiana.GEOMETRY AS geometry, \
				louisiana.COUNTYFP10 AS parishcode, \
				louisiana.VTDST10 AS precinctid, \
				louisiana.NAME AS parishname \
			FROM louisiana"

	@rm -rf tmp

exports/shp/precincts/parish/caddo-fullsize.shp: shp/precincts/caddo-crs.shp \
	exports/shp/water/red-river-fullsize.shp \
	exports/shp/water/black-bayou-fullsize.shp \
	exports/shp/water/caddo-lake-fullsize.shp \
	exports/shp/water/cross-lake-fullsize.shp

	@mkdir -p $(dir $@)
	@mkdir -p tmp

	@# Remove Red River.
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="caddo-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="red-river-fullsize">'\
				'<SrcDataSource>exports/shp/water/red-river-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/caddo-no-river.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, river.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'caddo-crs' AS precincts, 'red-river-fullsize' AS river"

	@# Remove Black Bayou.
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="caddo-no-river">'\
				'<SrcDataSource>tmp/caddo-no-river.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="black-bayou-fullsize">'\
				'<SrcDataSource>exports/shp/water/black-bayou-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/caddo-no-bayou.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, bayou.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'caddo-no-river' AS precincts, 'black-bayou-fullsize' AS bayou"

	@# Remove Caddo Lake.
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="caddo-no-bayou">'\
				'<SrcDataSource>tmp/caddo-no-bayou.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="caddo-lake-fullsize">'\
				'<SrcDataSource>exports/shp/water/caddo-lake-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/caddo-no-caddo-lake.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, lake.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'caddo-no-bayou' AS precincts, 'caddo-lake-fullsize' AS lake"

	@# Remove Cross Lake.
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="caddo-no-caddo-lake">'\
				'<SrcDataSource>tmp/caddo-no-caddo-lake.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="cross-lake-fullsize">'\
				'<SrcDataSource>exports/shp/water/cross-lake-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/caddo.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, lake.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'caddo-no-caddo-lake' AS precincts, 'cross-lake-fullsize' AS lake"

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/caddo.shp \
		-dialect sqlite \
		-sql "SELECT caddo.GEOMETRY AS geometry, \
				caddo.DISTRICT AS precinctid \
			FROM caddo"

	@rm -rf tmp

exports/shp/precincts/parish/east-baton-rouge-fullsize.shp: shp/precincts/east-baton-rouge-crs.shp \
	exports/shp/water/mississippi-river-fullsize.shp

	@mkdir -p $(dir $@)

	@# Remove Mississippi River.
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="east-baton-rouge-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="mississippi-river-fullsize">'\
				'<SrcDataSource>exports/shp/water/mississippi-river-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, river.GEOMETRY) AS geometry, \
					precincts.WARD AS ward, \
					precincts.VOTING_PRE AS precinctid \
				FROM 'east-baton-rouge-crs' AS precincts, 'mississippi-river-fullsize' AS river"

exports/shp/precincts/parish/lafayette-fullsize.shp: shp/precincts/lafayette-crs.shp
	@mkdir -p $(dir $@)
	@# NAME1_ field comes as "1", "37", "4 y & z". Want to export number only.
	@# https://www.sqlite.org/lang_corefunc.html
	@# http://stackoverflow.com/questions/11155886/split-firstname-and-lastname-in-sqlite
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT precincts.GEOMETRY AS geometry, \
				CASE \
					WHEN instr(precincts.NAME1_, ' ') = 0 THEN precincts.NAME1_ \
					WHEN instr(precincts.NAME1_, ' ') > 0 THEN substr(precincts.NAME1_, 1, instr(precincts.NAME1_, ' ') - 1) \
					END AS precinctid \
			FROM 'lafayette-crs' AS precincts"

exports/shp/precincts/parish/jefferson-fullsize.shp: shp/precincts/jefferson-crs.shp \
	exports/shp/water/gulf-of-mexico-fullsize.shp \
	exports/shp/water/mississippi-river-fullsize.shp \
	exports/shp/water/lake-salvador-fullsize.shp \
	exports/shp/water/lake-cataouatche-fullsize.shp \
	exports/shp/water/little-lake-fullsize.shp \
	exports/shp/water/turtle-bay-fullsize.shp \

	@mkdir -p $(dir $@)
	@mkdir -p tmp

	@# Lake Pontchartrain already removed in source.
	@# Remove Mississippi River.
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="jefferson-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="mississippi-river-fullsize">'\
				'<SrcDataSource>exports/shp/water/mississippi-river-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/jefferson-no-river.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, river.GEOMETRY) AS geometry, \
					precincts.PRECINCT AS precinctid \
				FROM 'jefferson-crs' AS precincts, 'mississippi-river-fullsize' AS river"

	@# Gulf of Mexico
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="jefferson-no-river">'\
				'<SrcDataSource>tmp/jefferson-no-river.shp</SrcDataSource></OGRVRTLayer>'\
			'<OGRVRTLayer name="gulf-of-mexico-fullsize">'\
				'<SrcDataSource>exports/shp/water/gulf-of-mexico-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/jefferson-no-gulf.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, gulf.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'jefferson-no-river' AS precincts, 'gulf-of-mexico-fullsize' AS gulf"

	@# Lake Salvador
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="jefferson-no-gulf">'\
				'<SrcDataSource>tmp/jefferson-no-gulf.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="lake-salvador-fullsize">'\
				'<SrcDataSource>exports/shp/water/lake-salvador-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/jefferson-no-salvador.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, lake.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'jefferson-no-gulf' AS precincts, 'lake-salvador-fullsize' AS lake"

	@# Lake Cataouatche
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="jefferson-no-salvador">'\
				'<SrcDataSource>tmp/jefferson-no-salvador.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="lake-cataouatche-fullsize">'\
				'<SrcDataSource>exports/shp/water/lake-cataouatche-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/jefferson-no-cataouatche.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, lake.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'jefferson-no-salvador' AS precincts, 'lake-cataouatche-fullsize' AS lake"

	@# Little Lake
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="jefferson-no-cataouatche">'\
				'<SrcDataSource>tmp/jefferson-no-cataouatche.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="little-lake-fullsize">'\
				'<SrcDataSource>exports/shp/water/little-lake-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/jefferson-no-little-lake.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, lake.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'jefferson-no-cataouatche' AS precincts, 'little-lake-fullsize' AS lake"

	@# Turtle Bay
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="jefferson-no-little-lake">'\
				'<SrcDataSource>tmp/jefferson-no-little-lake.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="turtle-bay-fullsize">'\
				'<SrcDataSource>exports/shp/water/turtle-bay-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			tmp/jefferson.shp /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, bay.GEOMETRY) AS geometry, \
					precincts.* \
				FROM 'jefferson-no-little-lake' AS precincts, 'turtle-bay-fullsize' AS bay"

	@# Groups and runs st_union to merge split precincts. Also dedupes.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/jefferson.shp \
		-overwrite \
		-dialect sqlite \
		-sql "SELECT DISTINCT precinctid, St_Union(ST_Buffer(GEOMETRY, 0.0000001)) AS geometry \
			FROM jefferson \
			GROUP BY precinctid"

	@rm -rf tmp

exports/shp/precincts/parish/orleans-fullsize.shp: shp/precincts/orleans-crs.shp \
	exports/shp/water/mississippi-river-fullsize.shp

	@mkdir -p $(dir $@)

	@# Remove Mississippi River. Lake Pontchartrain already removed in source.
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="orleans-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="mississippi-river-fullsize">'\
				'<SrcDataSource>exports/shp/water/mississippi-river-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, river.GEOMETRY) AS geometry, \
					precincts.PRECINCTID AS precinctid, \
					precincts.COUNTY AS parishname \
				FROM 'orleans-crs' AS precincts, 'mississippi-river-fullsize' AS river"

exports/shp/precincts/parish/st-tammany-fullsize.shp: shp/precincts/st-tammany-crs.shp \
	exports/shp/water/lake-pontchartrain-fullsize.shp

	@mkdir -p $(dir $@)

	@# Remove Lake Pontchartrain.
	@echo '<OGRVRTDataSource>'\
			'<OGRVRTLayer name="st-tammany-crs">'\
				'<SrcDataSource>$<</SrcDataSource>'\
			'</OGRVRTLayer>'\
			'<OGRVRTLayer name="lake-pontchartrain-fullsize">'\
				'<SrcDataSource>exports/shp/water/lake-pontchartrain-fullsize.shp</SrcDataSource>'\
			'</OGRVRTLayer>'\
		'</OGRVRTDataSource>' | \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			$@ /vsistdin/ \
			-dialect sqlite \
			-sql "SELECT ST_Difference(precincts.GEOMETRY, lake.GEOMETRY) AS geometry, \
					precincts.GEOMETRY, \
					precincts.VOTE00 AS precinctid \
				FROM 'st-tammany-crs' AS precincts, 'lake-pontchartrain-fullsize' AS lake \
				WHERE precincts.VTD2010 != 'ZZZZZZ'"

# Convert SHP to GeoJSON
exports/geojson/precincts/state/%-fullsize.json: exports/shp/precincts/state/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
			$@ $<
exports/geojson/precincts/parish/%-fullsize.json: exports/shp/precincts/parish/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
			$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/precincts/state/%-fullsize.json: exports/geojson/precincts/state/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<
exports/topojson/precincts/parish/%-fullsize.json: exports/geojson/precincts/parish/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/precincts/state/louisiana-simplified.json: exports/topojson/precincts/state/louisiana-fullsize.json
	@mkdir -p $(dir $@)
	@# TODO: Could simplify/quantize even more.
	@topojson \
		--spherical \
		--properties \
		-s 1e-12 \
		-q 1e6 \
		-o $@ \
		-- $<

exports/topojson/precincts/parish/caddo-simplified.json: exports/topojson/precincts/parish/caddo-fullsize.json
	@mkdir -p $(dir $@)
	@# The raw file has gaps and simplifications, so okay to simplify heavily.
	@topojson \
		--spherical \
		--properties \
		-s 1e-10 \
		-q 5e4 \
		-o $@ \
		-- $<
exports/topojson/precincts/parish/east-baton-rouge-simplified.json: exports/topojson/precincts/parish/east-baton-rouge-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-11 \
		-q 1e6 \
		-o $@ \
		-- $<
exports/topojson/precincts/parish/jefferson-simplified.json: exports/topojson/precincts/parish/jefferson-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-11 \
		-q 1.5E5 \
		-o $@ \
		-- $<
exports/topojson/precincts/parish/lafayette-simplified.json: exports/topojson/precincts/parish/lafayette-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-12 \
		-q 1e6 \
		-o $@ \
		-- $<
exports/topojson/precincts/parish/orleans-simplified.json: exports/topojson/precincts/parish/orleans-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-11 \
		-q 1e6 \
		-o $@ \
		-- $<
exports/topojson/precincts/parish/st-tammany-simplified.json: exports/topojson/precincts/parish/st-tammany-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-11 \
		-q 1e6 \
		-o $@ \
		-- $<

# Convert simplified TopoJSON to simplified GeoJSON
exports/geojson/precincts/state/%-simplified.json: exports/topojson/precincts/state/%-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@
exports/geojson/precincts/parish/%-simplified.json: exports/topojson/precincts/parish/%-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@

# Convert simplified GeoJSON to simplified shapefile
exports/shp/precincts/state/%-simplified.shp: exports/geojson/precincts/state/%-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<
exports/shp/precincts/parish/%-simplified.shp: exports/geojson/precincts/parish/%-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<

precincts: \
	exports/shp/precincts/parish/caddo-simplified.shp \
	exports/shp/precincts/parish/east-baton-rouge-simplified.shp \
	exports/shp/precincts/parish/lafayette-simplified.shp \
	exports/shp/precincts/parish/jefferson-simplified.shp \
	exports/shp/precincts/parish/orleans-simplified.shp \
	exports/shp/precincts/parish/st-tammany-simplified.shp \
	exports/shp/precincts/state/louisiana-simplified.shp


##############
#            #
#  Property  #
#            #
##############

# Download New Orleans parcel data
zip/property/parcels/NOLA_Parcels.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'https://data.nola.gov/api/geospatial/e962-egyh?method=export&format=Shapefile'
	@mv $@.download $@
zip/property/buildings/louisiana-latest.shp.zip:
	@# http://download.geofabrik.de/north-america/us/louisiana.html
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'http://download.geofabrik.de/north-america/us/$(notdir $@)'
	@mv $@.download $@

# Unzip
shp/property/parcels/geo_export_1f635c90-de74-4530-bfec-bf3e12827f60.shp: zip/buildings/parcels/NOLA_Parcels.zip
	@mkdir -p $(dir $@)
	@unzip -q -o -d $@ $<
shp/property/buildings/buildings.shp: zip/property/buildings/louisiana-latest.shp.zip
	@mkdir -p $(dir $@)
	@rm -rf tmp && mkdir tmp
	@unzip -q -o -d tmp $<
	@cp tmp/buildings* $(dir $@)
	@rm -rf tmp

# Convert U.S. Census shapefiles to WGS 84.
shp/property/parcels/new-orleans-crs.shp: shp/property/parcels/geo_export_1f635c90-de74-4530-bfec-bf3e12827f60.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs 'EPSG:4326'
shp/property/buildings/la-osm-crs.shp: shp/property/buildings/buildings.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs 'EPSG:4326'

exports/shp/property/parcels/new-orleans-fullsize.shp: shp/property/parcels/new-orleans-crs.shp
	@mkdir -p $(dir $@)
	@rm -rf tmp && mkdir -p tmp

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/nonull.shp $<

	@dropdb --if-exists temp_db
	@createdb temp_db
	@psql temp_db -c "CREATE EXTENSION postgis;"
	@shp2pgsql -s 4326 tmp/nonull nonull | psql -d temp_db
	@psql temp_db -c "CREATE INDEX nonull_index ON nonull USING GIST (geom);"

	@psql temp_db -c "DROP TABLE IF EXISTS singleparts;"
	@psql temp_db -c "CREATE TABLE singleparts AS \
		SELECT geopin, \
			(ST_Dump(geom)).geom AS singleparts_geom \
		FROM nonull;"

	@psql temp_db -c "CREATE INDEX singleparts_index ON singleparts USING GIST (singleparts_geom);"
	@psql temp_db -c "ALTER TABLE singleparts ADD COLUMN sqft double precision;"
	@psql temp_db -c "ALTER TABLE singleparts ADD COLUMN sqmi double precision;"
	@psql temp_db -c "UPDATE singleparts \
		SET sqft = ST_Area(singleparts_geom);"
	@psql temp_db -c "UPDATE singleparts \
		SET sqmi = ST_Area(singleparts_geom)*POWER(0.3048,2);"

	@pgsql2shp -f tmp/nonull.shp temp_db "SELECT * \
		FROM singleparts \
		WHERE sqmi != 0 AND \
			  sqmi IS NOT NULL;"

	@dropdb temp_db

	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/nonull.shp \
		-dialect sqlite \
		-sql "SELECT GEOPIN, \
				Geometry \
			FROM nonull"

	@rm -rf tmp

exports/shp/property/buildings/la-osm-fullsize.shp: shp/property/buildings/la-osm-crs.shp

	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT osm_id, \
				Geometry \
			FROM 'la-osm-crs'"

# Convert SHP to GeoJSON
exports/geojson/property/parcels/new-orleans-fullsize.json: exports/shp/property/parcels/new-orleans-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
			$@ $<
exports/geojson/property/buildings/la-osm-fullsize.json: exports/shp/property/buildings/la-osm-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
			$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/property/parcels/new-orleans-fullsize.json: exports/geojson/property/parcels/new-orleans-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<
exports/topojson/property/buildings/la-osm-fullsize.json: exports/geojson/property/buildings/la-osm-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

property: \
	exports/topojson/property/parcels/new-orleans-fullsize.json \
	exports/topojson/property/buildings/la-osm-fullsize.json


###########
#         #
#  Water  #
#         #
###########

# Download U.S. Census data
zip/water/tl_2015_%_areawater.zip:
	@mkdir -p $(dir $@)
	@curl -sS -o $@.download 'ftp://ftp2.census.gov/geo/tiger/TIGER2015/AREAWATER/$(notdir $@)'
	@mv $@.download $@

# Unzip U.S. Census data
shp/water/tl_2015_%_areawater.shp: zip/water/tl_2015_%_areawater.zip
	@mkdir -p $(dir $@)
	@unzip -q -o -d $(dir $@) $<

# Convert U.S. Census shapefiles to WGS 84.
shp/water/tl_2015_%_areawater-crs.shp: shp/water/tl_2015_%_areawater.shp
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-t_srs 'EPSG:4326'

# Selecting relevant features of counties and parishes along Mississippi River
shp/water/tl_2015_28055_areawater-ms-river-features.shp: shp/water/tl_2015_28055_areawater-crs.shp
	@# Issaquena County (055)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110340680889" OR \
				HYDROID = "1102213267559" OR \
				HYDROID = "1102213267560"'
shp/water/tl_2015_28149_areawater-ms-river-features.shp: shp/water/tl_2015_28149_areawater-crs.shp
	@# Warren County (149)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110514218126" OR \
				HYDROID = "110514218125" OR \
				HYDROID = "110514218127" OR \
				HYDROID = "110514218342"'
shp/water/tl_2015_28021_areawater-ms-river-features.shp: shp/water/tl_2015_28021_areawater-crs.shp
	@# Claiborne County (021)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1102213069121" OR \
				HYDROID = "110513956926"'
shp/water/tl_2015_28063_areawater-ms-river-features.shp: shp/water/tl_2015_28063_areawater-crs.shp
	@# Jefferson County (063)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110805477038" OR \
				HYDROID = "110805477039"'
shp/water/tl_2015_28001_areawater-ms-river-features.shp: shp/water/tl_2015_28001_areawater-crs.shp
	@# Adams County (001)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110513669976"'
shp/water/tl_2015_28157_areawater-ms-river-features.shp: shp/water/tl_2015_28157_areawater-crs.shp
	@# Wilkinson County (157)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1101193844330" OR \
				HYDROID = "1101193844359"'
shp/water/tl_2015_22035_areawater-ms-river-features.shp: shp/water/tl_2015_22035_areawater-crs.shp
	@# East Carroll Parish (035)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110465450505" OR \
				HYDROID = "110465450506" OR \
				HYDROID = "110465450508" OR \
				HYDROID = "110465450510"'
shp/water/tl_2015_22065_areawater-ms-river-features.shp: shp/water/tl_2015_22065_areawater-crs.shp
	@# Madison Parish (065)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110469092180" OR \
				HYDROID = "110469092179" OR \
				HYDROID = "110469092177"'
shp/water/tl_2015_22107_areawater-ms-river-features.shp: shp/water/tl_2015_22107_areawater-crs.shp
	@# Tensas Parish (107)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110511027323" OR \
				HYDROID = "110511027210" OR \
				HYDROID = "110511027209"'
shp/water/tl_2015_22029_areawater-ms-river-features.shp: shp/water/tl_2015_22029_areawater-crs.shp
	@# Concordia Parish (029)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110465442145" OR \
				HYDROID = "110465442146" OR \
				HYDROID = "110465442143" OR \
				HYDROID = "110465442144" OR \
				HYDROID = "110465442345" OR \
				HYDROID = "110465442147"'
shp/water/tl_2015_22125_areawater-ms-river-features.shp: shp/water/tl_2015_22125_areawater-crs.shp
	@# West Feliciana Parish (125)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1102213069158" OR \
				HYDROID = "1102390448523" OR \
				HYDROID = "110510925155" OR \
				HYDROID = "1102390448515" OR \
				HYDROID = "1102216246222"'
shp/water/tl_2015_22121_areawater-ms-river-features.shp: shp/water/tl_2015_22121_areawater-crs.shp
	@# West Baton Rouge Parish (121)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "11080473761" OR \
				HYDROID = "1102214490138"'
shp/water/tl_2015_22033_areawater-ms-river-features.shp: shp/water/tl_2015_22033_areawater-crs.shp
	@# East Baton Rouge Parish (033)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110507790752"'
shp/water/tl_2015_22047_areawater-ms-river-features.shp: shp/water/tl_2015_22047_areawater-crs.shp
	@# Iberville Parish (047)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "11081526535"'
shp/water/tl_2015_22005_areawater-ms-river-features.shp: shp/water/tl_2015_22005_areawater-crs.shp
	@# Ascension Parish (005)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1102214490137"'
shp/water/tl_2015_22093_areawater-ms-river-features.shp: shp/water/tl_2015_22093_areawater-crs.shp
	@# St. James Parish (093)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "11054202260"'
shp/water/tl_2015_22095_areawater-ms-river-features.shp: shp/water/tl_2015_22095_areawater-crs.shp
	@# St. John the Baptist Parish (095)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1104493000535"'
shp/water/tl_2015_22089_areawater-ms-river-features.shp: shp/water/tl_2015_22089_areawater-crs.shp
	@# St. Charles Parish (089)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1104493000532"'
shp/water/tl_2015_22051_areawater-ms-river-features.shp: shp/water/tl_2015_22051_areawater-crs.shp
	@# Jefferson Parish (051)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110469043508"'
shp/water/tl_2015_22071_areawater-ms-river-features.shp: shp/water/tl_2015_22071_areawater-crs.shp
	@# Orleans Parish (071)
	@# There is a sliver-shaped hole that has to be filled in this portion.
	@# See this post for an explanation of the PostGIS function below:
	@# http://geospatial.commons.gc.cuny.edu/2013/11/04/filling-in-holes-with-postgis/
	@mkdir -p tmp
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/msriverorleans.shp $< \
		-where 'HYDROID = "1102214490140" OR \
				HYDROID = "1102216207626" OR \
				HYDROID = "110469170820"'
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/msriverorleans.shp \
		-dialect sqlite \
		-sql 'SELECT ST_Collect(ST_MakePolygon(geom)) AS geom, * \
			FROM ( \
			    SELECT ST_ExteriorRing(msriverorleans.GEOMETRY) AS geom, * \
			    FROM msriverorleans \
			) AS s \
			GROUP BY HYDROID'
	@rm -rf tmp
shp/water/tl_2015_22087_areawater-ms-river-features.shp: shp/water/tl_2015_22087_areawater-crs.shp
	@# St. Bernard Parish (087)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110507905010" OR \
				HYDROID = "110507911178" OR \
				HYDROID = "110507905009"'
shp/water/tl_2015_22075_areawater-ms-river-features.shp: shp/water/tl_2015_22075_areawater-crs.shp
	@# Plaquemines Parish (075)
	@# The feature with HYDROID = '1102295075770' extends up into the Mississippi River.
	@# To avoid this, clip the feature to only include the river portion of the feature.
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-clipsrc -95.0 29.083 -80.0 35.0 \
		-where 'HYDROID = "1102295075770" OR \
				HYDROID = "11081627078"'

# Red River
shp/water/tl_2015_22015_areawater-red-river-features.shp: shp/water/tl_2015_22015_areawater-crs.shp
	@# Bossier Parish (015)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110465281085" OR \
				HYDROID = "1103700178476" OR \
				HYDROID = "110465281106" OR \
				HYDROID = "110465281087" OR \
				HYDROID = "1103700178474" OR \
				HYDROID = "110465281103" OR \
				HYDROID = "110465281095" OR \
				HYDROID = "110465281096" OR \
				HYDROID = "110465281102" OR \
				HYDROID = "1103700178475" OR \
				HYDROID = "110465281108" OR \
				HYDROID = "1104762759584" OR \
				HYDROID = "110465281099" OR \
				HYDROID = "110465281107" OR \
				HYDROID = "110465281080" OR \
				HYDROID = "110465281081" OR \
				HYDROID = "110465281082" OR \
				HYDROID = "110465281083" OR \
				HYDROID = "110465281094" OR \
				HYDROID = "110465281093" OR \
				HYDROID = "110465281092" OR \
				HYDROID = "110465281091" OR \
				HYDROID = "110465281090" OR \
				HYDROID = "110465281089" OR \
				HYDROID = "110465281088" OR \
				HYDROID = "110465281315" OR \
				HYDROID = "110465281097"'
shp/water/tl_2015_22017_areawater-red-river-features.shp: shp/water/tl_2015_22017_areawater-crs.shp
	@# Caddo Parish (017)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110585169260" OR \
				HYDROID = "110585174635" OR \
				HYDROID = "110585169265" OR \
				HYDROID = "110585169229" OR \
				HYDROID = "1103700178473" OR \
				HYDROID = "1103700178469" OR \
				HYDROID = "110585169269" OR \
				HYDROID = "110585169231" OR \
				HYDROID = "1103700178459" OR \
				HYDROID = "110585169225" OR \
				HYDROID = "110585169233" OR \
				HYDROID = "1104469987400" OR \
				HYDROID = "1104762759583" OR \
				HYDROID = "110585169235" OR \
				HYDROID = "110585169239" OR \
				HYDROID = "110585169236" OR \
				HYDROID = "110585174537" OR \
				HYDROID = "110585169261" OR \
				HYDROID = "110585169270" OR \
				HYDROID = "110585169266" OR \
				HYDROID = "110585169226" OR \
				HYDROID = "110585169256" OR \
				HYDROID = "110585169253" OR \
				HYDROID = "110585169264" OR \
				HYDROID = "110585169241" OR \
				HYDROID = "110585169230" OR \
				HYDROID = "110585169267" OR \
				HYDROID = "110585169232"'

# Black Bayou
shp/water/tl_2015_22017_areawater-black-bayou-features.shp: shp/water/tl_2015_22017_areawater-crs.shp
	@# Caddo Parish (089)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110585172537" OR \
				HYDROID = "110585174659" OR \
				HYDROID = "110585174412" OR \
				HYDROID = "110585174669"'

# Caddo Lake
shp/water/tl_2015_22017_areawater-caddo-lake-features.shp: shp/water/tl_2015_22017_areawater-crs.shp
	@# Caddo Parish (089)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110585170274" OR \
				HYDROID = "110585171112" OR \
				HYDROID = "110585174526" OR \
				HYDROID = "110585170442" OR \
				HYDROID = "110585170593" OR \
				HYDROID = "110585170499"'
shp/water/tl_2015_48203_areawater-caddo-lake-features.shp: shp/water/tl_2015_48203_areawater-crs.shp
	@# Harrison County, Texas (48203)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110782899276" OR \
				HYDROID = "110782899290"'
shp/water/tl_2015_48315_areawater-caddo-lake-features.shp: shp/water/tl_2015_48315_areawater-crs.shp
	@# Marion County, Texas (48203)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110781257841"'

# Cross Lake
shp/water/tl_2015_22017_areawater-cross-lake-features.shp: shp/water/tl_2015_22017_areawater-crs.shp
	@# Caddo Parish (089)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110585174628" OR \
				HYDROID = "110585174674" OR \
				HYDROID = "110585170377" OR \
				HYDROID = "110585170381"'

# Lake Cataouatche
shp/water/tl_2015_22089_areawater-lake-cataouatche-features.shp: shp/water/tl_2015_22089_areawater-crs.shp
	@# St. Charles Parish (089)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1102390332954" OR \
				HYDROID = "110466955622"'
shp/water/tl_2015_22051_areawater-lake-cataouatche-features.shp: shp/water/tl_2015_22051_areawater-crs.shp
	@# Jefferson Parish (051)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110469043504"'

# Lake Salvador
shp/water/tl_2015_22089_areawater-lake-salvador-features.shp: shp/water/tl_2015_22089_areawater-crs.shp
	@# St. Charles Parish (089)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1102390332995"'
shp/water/tl_2015_22051_areawater-lake-salvador-features.shp: shp/water/tl_2015_22051_areawater-crs.shp
	@# Jefferson Parish (051)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110469043466" OR \
			HYDROID = "110469044017" OR \
			HYDROID = "110469043476"'
shp/water/tl_2015_22057_areawater-lake-salvador-features.shp: shp/water/tl_2015_22057_areawater-crs.shp
	@# Lafourche Parish (057)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110518572263" OR \
				HYDROID = "110518572225" OR \
				HYDROID = "110518572317" OR \
				HYDROID = "110518572264" OR \
				HYDROID = "110518572265"'

# Little Lake
shp/water/tl_2015_22051_areawater-little-lake-features.shp: shp/water/tl_2015_22051_areawater-crs.shp
	@# Jefferson Parish (051)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		-where 'HYDROID = "110469043451"' \
		$@ $<
shp/water/tl_2015_22057_areawater-little-lake-features.shp: shp/water/tl_2015_22057_areawater-crs.shp
	@# Lafourche Parish (057)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110518572219" OR \
				HYDROID = "110518572195" OR \
				HYDROID = "110518572190" OR \
				HYDROID = "110518573210" OR \
				HYDROID = "110518572447" OR \
				HYDROID = "110518573591"'

# The Pen
shp/water/tl_2015_22051_areawater-the-pen-features.shp: shp/water/tl_2015_22051_areawater-crs.shp
	@# Jefferson Parish (051)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110469043465"'

# Turtle Bay
shp/water/tl_2015_22051_areawater-turtle-bay-features.shp: shp/water/tl_2015_22051_areawater-crs.shp
	@# Jefferson Parish (051)
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110469043455"'

# Gulf of Mexico features
shp/water/tl_2015_22023_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22023_areawater-crs.shp
	@# Cameron Parish (023)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110441630367"'
shp/water/tl_2015_22113_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22113_areawater-crs.shp
	@# Vermilion Parish (113)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1102214410271" OR \
				HYDROID = "110456807941" OR \
				HYDROID = "1102390119247"'
shp/water/tl_2015_22045_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22045_areawater-crs.shp
	@# Iberia Parish (045)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110468930422" OR \
				HYDROID = "110468930924" OR \
				HYDROID = "110468930424" OR \
				HYDROID = "110468930423" OR \
				HYDROID = "110468930925" OR \
				HYDROID = "110468930458" OR \
				HYDROID = "110468930461" OR \
				HYDROID = "110468930425"'
shp/water/tl_2015_22101_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22101_areawater-crs.shp
	@# St. Mary Parish (101)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110444747440" OR \
				HYDROID = "1102390119031" OR \
				HYDROID = "1102390118908" OR \
				HYDROID = "110444747441" OR \
				HYDROID = "1102390119074" OR \
				HYDROID = "1102390117358" OR \
				HYDROID = "1102390119563" OR \
				HYDROID = "110444749627"'
shp/water/tl_2015_22109_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22109_areawater-crs.shp
	@# Terrebonne Parish (109)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "11054216177" OR \
				HYDROID = "11054211544" OR \
				HYDROID = "11054216176" OR \
				HYDROID = "11054223976" OR \
				HYDROID = "11054219767" OR \
				HYDROID = "11054220571" OR \
				HYDROID = "11054209445" OR \
				HYDROID = "11054216518" OR \
				HYDROID = "11054219061" OR \
				HYDROID = "11054227999" OR \
				HYDROID = "11054223075" OR \
				HYDROID = "11054218298" OR \
				HYDROID = "11054219584" OR \
				HYDROID = "11054217722" OR \
				HYDROID = "11054209736" OR \
				HYDROID = "11054208388" OR \
				HYDROID = "11054216196" OR \
				HYDROID = "11054208146" OR \
				HYDROID = "11054228005" OR \
				HYDROID = "11054226740" OR \
				HYDROID = "1103700136408"'
shp/water/tl_2015_22057_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22057_areawater-crs.shp
	@# Lafourche Parish (057)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110518572586" OR \
				HYDROID = "110518572274" OR \
				HYDROID = "110518572287" OR \
				HYDROID = "110518572276" OR \
				HYDROID = "110518572275" OR \
				HYDROID = "1102216631301" OR \
				HYDROID = "110518573217" OR \
				HYDROID = "1104493254140" OR \
				HYDROID = "1104493254310" OR \
				HYDROID = "110518573528" OR \
				HYDROID = "110518572283" OR \
				HYDROID = "110518572250" OR \
				HYDROID = "110518572168" OR \
				HYDROID = "110518572218" OR \
				HYDROID = "110518572165" OR \
				HYDROID = "110518572269" OR \
				HYDROID = "110518572217"'
shp/water/tl_2015_22051_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22051_areawater-crs.shp
	@# Jefferson Parish (051)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110469043494" OR \
				HYDROID = "1104493254309" OR \
				HYDROID = "1104493254139" OR \
				HYDROID = "110469043467" OR \
				HYDROID = "1102216201441" OR \
				HYDROID = "110469044191" OR \
				HYDROID = "1102390333013" OR \
				HYDROID = "110469044200" OR \
				HYDROID = "110469043745" OR \
				HYDROID = "110469043484" OR \
				HYDROID = "110469044167" OR \
				HYDROID = "110469043524" OR \
				HYDROID = "110469044189" OR \
				HYDROID = "110469043523" OR \
				HYDROID = "110469043442" OR \
				HYDROID = "110469044192" OR \
				HYDROID = "110469044193" OR \
				HYDROID = "110469043489" OR \
				HYDROID = "110469044212" OR \
				HYDROID = "110469044171"'
shp/water/tl_2015_22075_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22075_areawater-crs.shp
	@# Plaquemines Parish (075)
	@# The feature with HYDROID = '1102295075770' extends up into the Mississippi River.
	@# To avoid this, first clip the feature to only include the Gulf portion of the feature.
	@mkdir -p tmp
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/plaquemines-single.shp $< \
		-clipsrc -89.51 28.74 -88.89 29.083 \
		-where 'HYDROID = "1102295075770"'
	@# All the other Gulf features of Plaquemines Parish
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		tmp/plaquemines-others.shp $< \
		-where 'HYDROID = "11081624028" OR \
				HYDROID = "11081623715" OR \
				HYDROID = "11081623817" OR \
				HYDROID = "11081633109" OR \
				HYDROID = "11081626769" OR \
				HYDROID = "11081624022" OR \
				HYDROID = "11081633206" OR \
				HYDROID = "11081624030" OR \
				HYDROID = "11081624163" OR \
				HYDROID = "11081623931" OR \
				HYDROID = "11081633178" OR \
				HYDROID = "11081624024" OR \
				HYDROID = "11081624130" OR \
				HYDROID = "11081626588" OR \
				HYDROID = "11081624025" OR \
				HYDROID = "11081624187" OR \
				HYDROID = "1102390333224" OR \
				HYDROID = "11081623786" OR \
				HYDROID = "1102390332906" OR \
				HYDROID = "11081623978" OR \
				HYDROID = "11081623552" OR \
				HYDROID = "11081633115" OR \
				HYDROID = "11081623887" OR \
				HYDROID = "11081633191" OR \
				HYDROID = "11081633190" OR \
				HYDROID = "11081633068" OR \
				HYDROID = "11081633113" OR \
				HYDROID = "11081624035" OR \
				HYDROID = "11081624201" OR \
				HYDROID = "11081623882" OR \
				HYDROID = "11081624159" OR \
				HYDROID = "11081624109" OR \
				HYDROID = "11081623957" OR \
				HYDROID = "11081623941" OR \
				HYDROID = "11081623762" OR \
				HYDROID = "11081623759" OR \
				HYDROID = "11081623714" OR \
				HYDROID = "11081623836" OR \
				HYDROID = "11081623837" OR \
				HYDROID = "11081633210" OR \
				HYDROID = "11081623898" OR \
				HYDROID = "11081633201" OR \
				HYDROID = "11081633209" OR \
				HYDROID = "11081623798" OR \
				HYDROID = "11081624133" OR \
				HYDROID = "11081624180" OR \
				HYDROID = "11081624083" OR \
				HYDROID = "11081623787" OR \
				HYDROID = "11081623833" OR \
				HYDROID = "11081633153" OR \
				HYDROID = "11081623863" OR \
				HYDROID = "11081624016" OR \
				HYDROID = "11081623960" OR \
				HYDROID = "11081623880" OR \
				HYDROID = "11081624062" OR \
				HYDROID = "11081624064" OR \
				HYDROID = "11081624065" OR \
				HYDROID = "11081623646" OR \
				HYDROID = "11081623945" OR \
				HYDROID = "11081623793" OR \
				HYDROID = "11081624083" OR \
				HYDROID = "11081623863" OR \
				HYDROID = "11081623880" OR \
				HYDROID = "11081624065" OR \
				HYDROID = "11081633160" OR \
				HYDROID = "11081623793" OR \
				HYDROID = "11081623945" OR \
				HYDROID = "11081623914" OR \
				HYDROID = "11081624180" OR \
				HYDROID = "11081624133" OR \
				HYDROID = "11081623798" OR \
				HYDROID = "11081623635" OR \
				HYDROID = "11081633201" OR \
				HYDROID = "11081623898" OR \
				HYDROID = "11081624177" OR \
				HYDROID = "11081633210" OR \
				HYDROID = "11081623762" OR \
				HYDROID = "11081624094" OR \
				HYDROID = "11081623613"'
	@# Merge the two Plaquemines files
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/plaquemines-single.shp \
		-update \
		-append \
		-nln "tl_2015_22075_areawater-gulf-of-mexico-features"
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ tmp/plaquemines-others.shp \
		-update \
		-append \
		-nln "tl_2015_22075_areawater-gulf-of-mexico-features"

	@rm -rf tmp
shp/water/tl_2015_22087_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22087_areawater-crs.shp
	@# St. Bernard Parish (087)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110507910857" OR \
				HYDROID = "110507905016" OR \
				HYDROID = "110507904785" OR \
				HYDROID = "110507905054" OR \
				HYDROID = "110507910867" OR \
				HYDROID = "1104492838904" OR \
				HYDROID = "110507905053" OR \
				HYDROID = "110507904867" OR \
				HYDROID = "110507904989" OR \
				HYDROID = "110507904982" OR \
				HYDROID = "110507905040" OR \
				HYDROID = "110507905037" OR \
				HYDROID = "110507909599" OR \
				HYDROID = "110507905056" OR \
				HYDROID = "110507910850" OR \
				HYDROID = "110507905066" OR \
				HYDROID = "110507909687" OR \
				HYDROID = "110507904840" OR \
				HYDROID = "110507904871" OR \
				HYDROID = "110507909600" OR \
				HYDROID = "110507904783" OR \
				HYDROID = "110507904942" OR \
				HYDROID = "110507904843" OR \
				HYDROID = "110507904839" OR \
				HYDROID = "110507904845" OR \
				HYDROID = "110507904838" OR \
				HYDROID = "110507905025" OR \
				HYDROID = "110507904965" OR \
				HYDROID = "110507905029" OR \
				HYDROID = "110507905011" OR \
				HYDROID = "110507905022" OR \
				HYDROID = "110507905028" OR \
				HYDROID = "110507905005" OR \
				HYDROID = "110507904927" OR \
				HYDROID = "110507904977" OR \
				HYDROID = "110507905006"'
shp/water/tl_2015_22103_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_22103_areawater-crs.shp
	@# St. Tammany (103)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1102730928027" OR \
				HYDROID = "1104493254387" OR \
				HYDROID = "1104493254345"'
# Mississipi's (28) Gulf counties
shp/water/tl_2015_28045_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_28045_areawater-crs.shp
	@# Harrison County (047)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1104493254384" OR \
				HYDROID = "1104493254343" OR \
				HYDROID = "11092979163" OR \
				HYDROID = "11092979223" OR \
				HYDROID = "11092979209"'
shp/water/tl_2015_28047_areawater-gulf-of-mexico-features.shp: shp/water/tl_2015_28047_areawater-crs.shp
	@# Harrison County (047)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "110169774582" OR \
				HYDROID = "110169774602" OR \
				HYDROID = "110169774603" OR \
				HYDROID = "1104492838905"'

# Lake Pontchartrain features
shp/water/tl_2015_22095_areawater-lake-pontchartrain-features.shp: shp/water/tl_2015_22095_areawater-crs.shp
	@# St. John the Baptist Parish (095)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1104492831900"'
shp/water/tl_2015_22089_areawater-lake-pontchartrain-features.shp: shp/water/tl_2015_22089_areawater-crs.shp
	@# St. Charles Parish (089)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1104492831902"'
shp/water/tl_2015_22051_areawater-lake-pontchartrain-features.shp: shp/water/tl_2015_22051_areawater-crs.shp
	@# Jefferson Parish (051)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1104701918974" OR \
				HYDROID = "110469043868"'
shp/water/tl_2015_22071_areawater-lake-pontchartrain-features.shp: shp/water/tl_2015_22071_areawater-crs.shp
	@# Orleans Parish (071)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1104492831897"'
shp/water/tl_2015_22103_areawater-lake-pontchartrain-features.shp: shp/water/tl_2015_22103_areawater-crs.shp
	@# St. Tammany Parish (103)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "11082011201" OR \
				HYDROID = "1104701918973" OR \
				HYDROID = "1104492833578" OR \
				HYDROID = "11082013688"'
shp/water/tl_2015_22105_areawater-lake-pontchartrain-features.shp: shp/water/tl_2015_22105_areawater-crs.shp
	@# Tangipahoa Parish (105)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-where 'HYDROID = "1104492831901" OR \
				HYDROID = "1104492833577"'

# Merge Mississippi River shapefiles
shp/water/missriver.shp: \
	shp/water/tl_2015_28055_areawater-ms-river-features.shp \
	shp/water/tl_2015_28149_areawater-ms-river-features.shp \
	shp/water/tl_2015_28021_areawater-ms-river-features.shp \
	shp/water/tl_2015_28063_areawater-ms-river-features.shp \
	shp/water/tl_2015_28001_areawater-ms-river-features.shp \
	shp/water/tl_2015_28157_areawater-ms-river-features.shp \
	shp/water/tl_2015_22035_areawater-ms-river-features.shp \
	shp/water/tl_2015_22065_areawater-ms-river-features.shp \
	shp/water/tl_2015_22107_areawater-ms-river-features.shp \
	shp/water/tl_2015_22029_areawater-ms-river-features.shp \
	shp/water/tl_2015_22125_areawater-ms-river-features.shp \
	shp/water/tl_2015_22121_areawater-ms-river-features.shp \
	shp/water/tl_2015_22033_areawater-ms-river-features.shp \
	shp/water/tl_2015_22047_areawater-ms-river-features.shp \
	shp/water/tl_2015_22005_areawater-ms-river-features.shp \
	shp/water/tl_2015_22093_areawater-ms-river-features.shp \
	shp/water/tl_2015_22095_areawater-ms-river-features.shp \
	shp/water/tl_2015_22089_areawater-ms-river-features.shp \
	shp/water/tl_2015_22051_areawater-ms-river-features.shp \
	shp/water/tl_2015_22071_areawater-ms-river-features.shp \
	shp/water/tl_2015_22087_areawater-ms-river-features.shp \
	shp/water/tl_2015_22075_areawater-ms-river-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln missriver \
			$@ $$file; \
	done
# Merge Red River shapefiles.
shp/water/redriver.shp: \
	shp/water/tl_2015_22015_areawater-red-river-features.shp \
	shp/water/tl_2015_22017_areawater-red-river-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln redriver \
			$@ $$file; \
	done
# Merge Black Bayou shapefiles.
shp/water/blackbayou.shp: \
	shp/water/tl_2015_22017_areawater-black-bayou-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln blackbayou \
			$@ $$file; \
	done
# Merge Caddo Lake shapefiles.
shp/water/caddolake.shp: \
	shp/water/tl_2015_22017_areawater-caddo-lake-features.shp \
	shp/water/tl_2015_48203_areawater-caddo-lake-features.shp \
	shp/water/tl_2015_48315_areawater-caddo-lake-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln caddolake \
			$@ $$file; \
	done
# Merge Cross Lake shapefiles.
shp/water/crosslake.shp: \
	shp/water/tl_2015_22017_areawater-cross-lake-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln crosslake \
			$@ $$file; \
	done
# Merge Lake Cataouatche shapefiles
shp/water/lakecataouatche.shp: \
	shp/water/tl_2015_22089_areawater-lake-cataouatche-features.shp \
	shp/water/tl_2015_22051_areawater-lake-cataouatche-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln lakecataouatche \
			$@ $$file; \
	done
# Merge Lake Salavador shapefiles
shp/water/lakesalvador.shp: \
	shp/water/tl_2015_22089_areawater-lake-salvador-features.shp \
	shp/water/tl_2015_22051_areawater-lake-salvador-features.shp \
	shp/water/tl_2015_22057_areawater-lake-salvador-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln lakesalvador \
			$@ $$file; \
	done
# Merge Little Lake shapefiles
shp/water/littlelake.shp: \
	shp/water/tl_2015_22057_areawater-little-lake-features.shp \
	shp/water/tl_2015_22051_areawater-little-lake-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln littlelake \
			$@ $$file; \
	done
# Merge The Pen shapefiles
shp/water/thepen.shp: shp/water/tl_2015_22051_areawater-the-pen-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln thepen \
			$@ $$file; \
	done
# Merge Turtle Bay shapefiles
shp/water/turtlebay.shp: shp/water/tl_2015_22051_areawater-turtle-bay-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln turtlebay \
			$@ $$file; \
	done
# Merge Gulf of Mexico shapefiles
shp/water/gulfofmexico.shp: \
	shp/water/tl_2015_22023_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22113_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22045_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22101_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22109_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22057_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22051_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22075_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22087_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_22103_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_28045_areawater-gulf-of-mexico-features.shp \
	shp/water/tl_2015_28047_areawater-gulf-of-mexico-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln gulfofmexico \
			$@ $$file; \
	done
# Merge Lake Pontchartrain shapefiles
shp/water/lakepontchartrain.shp: \
	shp/water/tl_2015_22095_areawater-lake-pontchartrain-features.shp \
	shp/water/tl_2015_22089_areawater-lake-pontchartrain-features.shp \
	shp/water/tl_2015_22051_areawater-lake-pontchartrain-features.shp \
	shp/water/tl_2015_22071_areawater-lake-pontchartrain-features.shp \
	shp/water/tl_2015_22103_areawater-lake-pontchartrain-features.shp \
	shp/water/tl_2015_22105_areawater-lake-pontchartrain-features.shp

	@for file in $^; do \
		ogr2ogr \
			-f 'ESRI Shapefile' \
			-update \
			-append \
			-nln lakepontchartrain \
			$@ $$file; \
	done

# Dissolve
exports/shp/water/mississippi-river-fullsize.shp: shp/water/missriver.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM missriver"
exports/shp/water/red-river-fullsize.shp: shp/water/redriver.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM redriver"
exports/shp/water/black-bayou-fullsize.shp: shp/water/blackbayou.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM blackbayou"
exports/shp/water/caddo-lake-fullsize.shp: shp/water/caddolake.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM caddolake"
exports/shp/water/cross-lake-fullsize.shp: shp/water/crosslake.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM crosslake"
exports/shp/water/lake-cataouatche-fullsize.shp: shp/water/lakecataouatche.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM lakecataouatche"
exports/shp/water/lake-salvador-fullsize.shp: shp/water/lakesalvador.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM lakesalvador"
exports/shp/water/little-lake-fullsize.shp: shp/water/littlelake.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM littlelake"
exports/shp/water/the-pen-fullsize.shp: shp/water/thepen.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM thepen"
exports/shp/water/turtle-bay-fullsize.shp: shp/water/turtlebay.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM turtlebay"
exports/shp/water/gulf-of-mexico-fullsize.shp: shp/water/gulfofmexico.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM gulfofmexico"
exports/shp/water/lake-pontchartrain-fullsize.shp: shp/water/lakepontchartrain.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $< \
		-dialect sqlite \
		-sql "SELECT St_Union(Geometry) FROM lakepontchartrain"

# Convert SHP to GeoJSON
exports/geojson/water/%-fullsize.json: exports/shp/water/%-fullsize.shp
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'GeoJSON' \
		$@ $<

# Convert GeoJSON to TopoJSON
exports/topojson/water/%-fullsize.json: exports/geojson/water/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--no-quantization \
		--properties \
		-o $@ \
		-- $<

# Simplify TopoJSON
exports/topojson/water/%-simplified.json: exports/topojson/water/%-fullsize.json
	@mkdir -p $(dir $@)
	@topojson \
		--spherical \
		--properties \
		-s 1e-11 \
		-q 1e6 \
		-o $@ \
		-- $<

# Convert simplified TopoJSON to simplified GeoJSON
exports/geojson/water/%-simplified.json: exports/topojson/water/%-simplified.json
	@mkdir -p $(dir $@)
	@python scripts/topo2geojson.py $< $@

# Convert simplified GeoJSON to simplified shapefile
exports/shp/water/%-simplified.shp: exports/geojson/water/%-simplified.json
	@mkdir -p $(dir $@)
	@ogr2ogr \
		-f 'ESRI Shapefile' \
		$@ $<

water: \
	exports/shp/water/black-bayou-simplified.shp \
	exports/shp/water/caddo-lake-simplified.shp \
	exports/shp/water/cross-lake-simplified.shp \
	exports/shp/water/gulf-of-mexico-simplified.shp \
	exports/shp/water/lake-cataouatche-simplified.shp \
	exports/shp/water/lake-pontchartrain-simplified.shp \
	exports/shp/water/lake-salvador-simplified.shp \
	exports/shp/water/little-lake-simplified.shp \
	exports/shp/water/mississippi-river-simplified.shp \
	exports/shp/water/red-river-simplified.shp \
	exports/shp/water/the-pen-simplified.shp \
	exports/shp/water/turtle-bay-simplified.shp
