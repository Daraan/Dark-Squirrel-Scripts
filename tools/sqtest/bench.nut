// Relative benchmark for the dfile/dblob search and string paths.
// Absolute times mean nothing (this is stock sq, not squirrel.osm); the ratios do.
dofile("stubs.nut", true)
dofile("assert.nut", true)
dofile("../../DScript File&Blob.nut", true)

function bench(label, iterations, fn){
	local t0 = clock()
	for (local i = 0; i < iterations; i++) fn()
	print(format("%-42s %8.3f s\n", label, clock() - t0))
}

function WriteTemp(name, contents){
	local f = ::file(name, "wb+")
	foreach (ch in contents) f.writen(ch, 'c')
	f.close()
	return name
}

local payload = ""
for (local i = 0; i < 4000; i++) payload += ((i % 26) + 65).tochar()

bench("tostring 4000 bytes x200", 200, function() { dblob(payload).tostring() })
bench("dblob.find m=9 fresh blob x200", 200, function() { dblob(payload + "ENVMAPVAR").find("ENVMAPVAR") })

local hay = dblob(payload + "ENVMAPVAR")
bench("dblob.find m=9 cached x2000", 2000, function() { hay.find("ENVMAPVAR") })

WriteTemp("tmp_bench.txt", payload + "ENVMAPVAR")
bench("dfile.find m=9 in 4000 bytes x200", 200, function() { dfile("tmp_bench.txt").find("ENVMAPVAR") })
