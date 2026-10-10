# Air Service (Uber Air) Take-Home Assignment

# Part 1

## New service: Uber Air

To further support the cause, we have (hypothetically!) launched another service: Uber Air.

Uber Air is a marketplace for sharing aeroplane rides.

On one side of the market there are aeroplane operators, ready to fly from anywhere to anywhere. On the other side of the market there are individuals and groups who need to get from A to B.

### Goal

After a few months of operating in Europe, we see that the service is doing great in some regions, while it hasn't taken off in others areas. We want to replicate the success in all of our regions and expand outwards, envisioning to facilitate 20% of all aeroplane rides across the globe in 2030.

To achieve the goal, we need to understand what are the drivers of growth:

- The kind of customers we serve well.

- The kind of use cases we cover (short or long, from where to where, low cost or premium, small or big planes etc).

- To make sure the business fits into our portfolio, we also need to monitor:
    - Daily/weekly/monthly active users.
    - Revenue and other metrics that we can compare to our older business lines.

### Data

We are providing you with small samples of datasets from our Uber Air system:

- `aeroplane_model.json`: A JSON file that holds information bout aeroplane models.
    - This file describes the available models on the market.

- `Uber Air data.xlsx` - a Google Sheets file with multiple tabs, representing tables about: trips, orders, aeroplanes, customers and customer groups.
    - Trips represent aeroplane rides.
    - Orders represent customers purchasing seats on those trips.
    - Aeroplanes holds information about individual aircrafts that operate on the platform.
    - ans so on...

### Task

Your task is to design a data model that enables monitoring and self-service analysis of the Uber Air service. Keep in mind the scale we plan to achieve. Apply industry best
practices to ensure reliability, scalability, maintainability, high quality and good user experience for your data users.

#### Deliverables

- A data model in a format that best describes all the data structures that you have envisioned for the use case, for example an ERD (entity relationship diagram) or a set of `CREATE TABLE...` statements in SQL.

- A code repository with a relevant part of the data model actually implemented in a tool, it doesn't have to be the full data model, present what you think shows your skills.
    - The repository doesn't have to be a functioning deployment, it's ok to submit code that can't be executed against anything, but the files you choose to submit should be logically complete and demonstrate your skillset.

- Additional context on why you have designed such a data model

- Comments on what would you do if you had more time for the task.

#### Tooling

This is the tooling that we currently have available for analytics:
- S3 for data storage
- Databricks for compute and data exploration
- dbt for data transformations
- Looker for reporting and self-service analytics
- GitHub to keep our scripts organised

> [!TIP]
> We encourage submissions that assume or make use of this stack, but alternatives are also welcome.

# Part 2

- Let's imagine you have implemented a pipeline that makes your data model from Part 1 available to users.

- As you can imagine, our business will evolve and become more complex over time, requiring changes in your data model.

- Let's also imagine you have absolutely no limitations on tooling or resources.

## Task

- How would you envision the ideal CI/CD process to implement these changes over time?

- What kind of environments, processes, tests and tools might be involved?

- How would your answer differ in the real world use case where resources are limited and perfect tooling might not be available?

- What are some of the low effort/short term and high effort/long term things you would suggest we implement?

> [!TIP]
> In your answers, share relevant experience from the past to back up your suggestions.
> In this part, we do not expect any practical output.

---

*Repository note (not part of the assignment): the supplied `aeroplane_model.json` dataset referenced above is archived at [`docs/aeroplane_model.json`](aeroplane_model.json); [`data/aeroplane_model.csv`](../data/aeroplane_model.csv) is the converted copy used by the implementation.*
