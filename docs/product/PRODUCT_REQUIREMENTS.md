# Product requirements (first slice)

## Purpose

AquaOS helps people working with borewell pumping systems understand the head, friction losses and power that a pump must provide, and explain those results to others.

## Users

| User | Need in this slice |
| --- | --- |
| Farmer | Understand a pumping calculation in plain language |
| Pump dealer | Check a configuration and explain it to a customer |
| Service technician | Check inputs and results against site readings |
| Distributor | Not served in this slice |

The advisor accepts `farmer`, `dealer` and `technician` as audiences.

## In scope

- Monorepo foundation for the web app and API
- Database schema and Row Level Security policies (SQL only)
- Hydraulic calculation engine with tests
- Hydraulic calculator page wired to the real API
- AI advisor explain endpoint with the mock provider

## Out of scope

- Authentication wired into the app
- Persistence of analyses
- Product catalogue UI
- Service management
- Verification of a real AI provider
- Playwright end-to-end tests
- Deployment

## Functional requirements

- **FR-1.** The calculator accepts the inputs defined in the API contract, including depths, levels, delivery height, pipe length and diameter, flow rate and efficiencies.
- **FR-2.** The calculator returns total dynamic head with a breakdown, pipe velocity and flow regime, flow in several units, power figures, assumptions, warnings and a disclaimer.
- **FR-3.** Invalid inputs are rejected with HTTP 422 using the contract's validation rules.
- **FR-4.** The advisor explains a calculation result for the selected audience. It does not change any number, and it returns a disclaimer.
- **FR-5.** If the advisor fails, the calculation result remains available to the user.
- **FR-6.** The database schema restricts row access with Row Level Security. It is not yet connected to the API.

## Principles

- Hydraulic calculations are deterministic. AI never performs or overrides them.
- No fabricated manufacturer products or pump curves.
- Service-role credentials never reach the browser.
- Simplified calculations are not certified engineering designs. Results must carry the disclaimer.

## Open questions

- Which authentication method and roles the app will use.
- How analyses will be stored and shared between users.
- Which AI provider will be used, and how its output will be verified.
- What source, if any, will be used for product and pump data.
