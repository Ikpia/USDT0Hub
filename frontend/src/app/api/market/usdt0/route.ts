import { NextResponse } from "next/server";

const GECKO_BASE = "https://api.geckoterminal.com/api/v2";
const USDT0_MAINNET = "0xaf37E8B6C9ED7f6318979f56Fc287d76c30847ff";

type GeckoPool = {
  attributes: {
    address: string;
    name: string;
    reserve_in_usd: string;
    base_token_price_usd: string;
    quote_token_price_usd: string;
    volume_usd?: { h24?: string };
    transactions?: { h24?: { buys: number; sells: number } };
  };
};

export async function GET() {
  try {
    const res = await fetch(
      `${GECKO_BASE}/networks/cfx/tokens/${USDT0_MAINNET}/pools`,
      {
        headers: {
          Accept: "application/json;version=20230302",
          "User-Agent": "usdt0hub-dashboard/1.0",
        },
        next: { revalidate: 300 },
      }
    );

    if (!res.ok) {
      return NextResponse.json(
        { error: `gecko_http_${res.status}` },
        { status: res.status }
      );
    }

    const json = (await res.json()) as { data?: GeckoPool[] };
    const pools = json.data ?? [];
    const topPool = [...pools].sort((a, b) => {
      const aReserve = Number(a.attributes.reserve_in_usd ?? "0");
      const bReserve = Number(b.attributes.reserve_in_usd ?? "0");
      return bReserve - aReserve;
    })[0];

    return NextResponse.json({
      source: "geckoterminal",
      network: "cfx",
      token: USDT0_MAINNET,
      poolCount: pools.length,
      topPool: topPool
        ? {
            address: topPool.attributes.address,
            name: topPool.attributes.name,
            reserveUsd: Number(topPool.attributes.reserve_in_usd ?? "0"),
            baseTokenPriceUsd: Number(
              topPool.attributes.base_token_price_usd ?? "0"
            ),
            quoteTokenPriceUsd: Number(
              topPool.attributes.quote_token_price_usd ?? "0"
            ),
            volume24hUsd: Number(
              topPool.attributes.volume_usd?.h24 ?? "0"
            ),
            buys24h: Number(topPool.attributes.transactions?.h24?.buys ?? 0),
            sells24h: Number(topPool.attributes.transactions?.h24?.sells ?? 0),
          }
        : null,
      fetchedAt: Date.now(),
    });
  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "unknown_error",
      },
      { status: 500 }
    );
  }
}
