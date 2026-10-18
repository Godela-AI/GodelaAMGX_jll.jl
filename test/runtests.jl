using Test

const TEST_FILES = ("test_aqua.jl", "test_check_concrete_structs.jl")
const TEST_SELECTED = isempty(ARGS) ? TEST_FILES : ARGS
all(file -> file in TEST_FILES, TEST_SELECTED) || error("Unknown test file; choose from $(TEST_FILES)")
for file in TEST_SELECTED
    include(file)
end
