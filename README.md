# How to run
Upon first start Phoenix does some shenanigans with `esbuild` and JS assets,
so please agree to whatever it asks.

```
make deps
make start
```

# UI
Please access `http://localhost:4000/` either from two different browsers of
from incognito mode to get sense of multiplayer game.

The UI itself is very basic, some of the expected errors (like game isn't found)
are handled but not visually shown due to my trully awesome frontend skills and
limited time. Watch server logs as well.

# CI
There is some limited CI set up through github actions, [check it out](.github/workflows/ci.yml)

## tests
Tests are covering good chunk of the engine and none of the frontend due to limited time.

## dialyzer
Most of the dialyzer stuf is in good order, except some phoenix related warnings
which are related to the phoenix itself and are [ignored](./dialyzer.ignore-warnings)

