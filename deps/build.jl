using BinaryProvider, Libdl

# Parse some basic command-line arguments
const verbose = "--verbose" in ARGS
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, String["libmbedcrypto"], :libmbedcrypto),
    LibraryProduct(prefix, String["libmbedtls"], :libmbedtls),
    LibraryProduct(prefix, String["libmbedx509"], :libmbedx509),
]

const juliaprefix = joinpath(Sys.BINDIR, "..")

juliaproducts = Product[
    LibraryProduct(juliaprefix, "libmbedtls", :libmbedtls)
    LibraryProduct(juliaprefix, "libmbedcrypto", :libmbedcrypto)
    LibraryProduct(juliaprefix, "libmbedx509", :libmbedx509)
]

# Download binaries from hosted location
bin_prefix = "https://github.com/JuliaWeb/MbedTLSBuilder/releases/download/v0.16.0"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, libc=:glibc) => ("$bin_prefix/MbedTLS.v2.13.1.aarch64-linux-gnu.tar.gz", "051b7b40911154196d0378bd41a2cc0182e4c5e3aa06506702adca36a875018f"),
    Linux(:aarch64, libc=:musl) => ("$bin_prefix/MbedTLS.v2.13.1.aarch64-linux-musl.tar.gz", "d031de3dd7723b647aa8dcb5fbe9777e7db0927e04a8cbf779a4a9da1f767061"),
    Linux(:armv7l, libc=:glibc, call_abi=:eabihf) => ("$bin_prefix/MbedTLS.v2.13.1.arm-linux-gnueabihf.tar.gz", "77adab909961fc750579c0fec87152b74048e466d8b9ca80df6d4f286fc92101"),
    Linux(:armv7l, libc=:musl, call_abi=:eabihf) => ("$bin_prefix/MbedTLS.v2.13.1.arm-linux-musleabihf.tar.gz", "a47e3d6bb09bb7564fea16dbe099e7b772f18128b99a5f92627a97dca3266f5d"),
    Linux(:i686, libc=:glibc) => ("$bin_prefix/MbedTLS.v2.13.1.i686-linux-gnu.tar.gz", "d35401469c134a151ab139e0fd400729f72c223ef8c0a736a76aae63c48dfa95"),
    Linux(:i686, libc=:musl) => ("$bin_prefix/MbedTLS.v2.13.1.i686-linux-musl.tar.gz", "2fa1b8674a3898eb08b3d28bd45fbfe022137a259edf407c564b5a817526647d"),
    Windows(:i686) => ("$bin_prefix/MbedTLS.v2.13.1.i686-w64-mingw32.tar.gz", "5fc0d5749fe644eb60cc5dda361831c0c64e6847559d1c6b719b185979e867ae"),
    Linux(:powerpc64le, libc=:glibc) => ("$bin_prefix/MbedTLS.v2.13.1.powerpc64le-linux-gnu.tar.gz", "8d36c2085f6cec55077fb7af485399a2b8d4a55033962c2a352d764fc153590f"),
    MacOS(:x86_64) => ("$bin_prefix/MbedTLS.v2.13.1.x86_64-apple-darwin14.tar.gz", "907df87621d4a63e1621c585cf351cf4d34a2e880c124f04cb4b404c690cc224"),
    Linux(:x86_64, libc=:glibc) => ("$bin_prefix/MbedTLS.v2.13.1.x86_64-linux-gnu.tar.gz", "46d14792f88781f19c30ec0e9fd1815d61906d9f002499d3e277e206da484a99"),
    Linux(:x86_64, libc=:musl) => ("$bin_prefix/MbedTLS.v2.13.1.x86_64-linux-musl.tar.gz", "fe43ca4323d295f2a05ff1ffde8c724ea43fad6a38d5b902dc8aee47a9160ad4"),
    FreeBSD(:x86_64) => ("$bin_prefix/MbedTLS.v2.13.1.x86_64-unknown-freebsd11.1.tar.gz", "537ab0cdc5fcfb0acc9bb6d013746f80007332b297f88423db1dc1306769f9b5"),
    Windows(:x86_64) => ("$bin_prefix/MbedTLS.v2.13.1.x86_64-w64-mingw32.tar.gz", "99d7f51190b841731139a5a561b7ee54fe99c1688c27ca3efd75a047da88eacf"),
)

# First, check to see if we're all satisfied
gpl = haskey(ENV, "USE_GPL_MBEDTLS")
forcebuild = parse(Bool, get(ENV, "FORCE_BUILD", "false")) || gpl
done = false
if any(!satisfied(p; verbose=verbose) for p in products) || forcebuild
    if haskey(download_info, platform_key()) && !forcebuild
        # Download and install binaries
        url, tarball_hash = download_info[platform_key()]
        install(url, tarball_hash; prefix=prefix, force=true, verbose=verbose)
        done = satisfied(p; verbose=verbose) for p in products)
        done && @info "using prebuilt binaries"
    end
    if !done && all(satisfied(p; verbose=verbose) for p in juliaproducts) && !forcebuild
        @info "using julia-shippied binaries"
        products = juliaproducts
    else
        @info "attempting source build"
        VERSION = "2.13.0"
        url, hash = haskey(ENV, "USE_GPL_MBEDTLS") ?
            ("https://tls.mbed.org/download/mbedtls-$VERSION-gpl.tgz", "a08ddf08aae55fc4f48fbc6281fcb08bc5c53ed53ffd15355ee0d75ec32b53ae") :
            ("https://tls.mbed.org/download/mbedtls-$VERSION-apache.tgz", "593b4e4d2e1629fc407ab4750d69fa309a0ddb66565dc3deb5b60eddbdeb06da")
        download_verify(url, hash, joinpath(@__DIR__, "mbedtls.tgz"), force=true, verbose=true)
        unpack(joinpath(@__DIR__, "mbedtls.tgz"), @__DIR__; verbose=true)
        withenv("VERSION"=>VERSION) do
            run(Cmd(`./build.sh`, dir=@__DIR__))
        end
        if any(!satisfied(p; verbose=verbose) for p in products)
            error("attempted to build mbedtls shared libraries, but they couldn't be located (deps/usr/lib)")
        end
    end
end

write_deps_file(joinpath(@__DIR__, "deps.jl"), products, verbose=verbose)
