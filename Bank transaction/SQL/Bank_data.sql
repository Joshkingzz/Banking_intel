use bank

-- copy structure and data for each table
select * into fact_copy from fact;
select * into branch_copy from branch;
select * into category_copy from category;
select * into subcategory_copy from subcategory;
select * into channel_copy from channel;
select * into currency_copy from currency;
select * into date_copy from [date];
select * into offer_copy from offer;
select * into segment_copy from segment;
select * into txn_type_copy from txn_type;

--Confirming the entire dataset
select * from fact as j
inner join branch as a on j.branchcityid = a.branchcityid
inner join category as b on j.productcategoryid = b.productcategoryid
inner join subcategory as c on j.productsubcategoryid = c.productsubcategoryid
inner join channel as d on j.channelid = d.channelid
inner join currency as e on j.currencyid = e.currencyid
inner join [date] as f on j.transactiondateid = f.transactiondateid
inner join offer as g on j.recommendedofferid = g.recommendedofferid
inner join segment as h on j.customersegmentid = h.customersegmentid
inner join txn_type as i on j.transactiontypeid = i.transactiontypeid;

--Adding new column that unifies the currencu unit
alter table fact
add fee_to_amt float, 
    fee_to_income float,
    amt float,
    accumulated_fees float,
    fees float,
    income float;

alter table fact
drop column 
    
    amt ,
    accumulated_fees,
    fees,
    income



update Fact 
set Amt = Amount * 0.88
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'USD'

update Fact 
set Amt = Amount
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'EUR'

update Fact 
set Accumulated_fees = creditcardfees + insurancefees + latepaymentamount
from Fact

update Fact 
set Fees = accumulated_fees * 0.88
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'USD'

update Fact 
set Fees = accumulated_fees
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'EUR'

update Fact 
set Income = MonthlyIncome * 0.88
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'USD'

update Fact 
set income = MonthlyIncome
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'EUR'

update fact
set fee_to_amt = fees/amt

update fact
set fee_to_income = fees/income




--dropping unwanted columns
Alter table fact
drop column monthlyincome, Amount, creditcardfees, accumulated_fees, insurancefees, latepaymentamount


--A) CUSTOMER INSIGHT AND SEGMENTATION
--1) Which Customer segment are most transaction active
select h.CustomerSegment, count(j.transactionID) as Transaction_Volume from fact as j 
inner join segment as h on j.customersegmentid = h.customersegmentid
group by h.customersegment
order by Transaction_Volume desc

--2) Which financial products are most popular within each segment
with popular_product as (
    select 
        h.CustomerSegment as Customer_segment,
        b.ProductCategory as product_category,
        count(j.TransactionID) as Transaction_volume,
        row_number() over ( partition by h.customersegment order by count(*) desc
        ) as rank
    from fact as j
    inner join category as b on j.productcategoryid = b.productcategoryid
    inner join segment as h on j.customersegmentid = h.customersegmentid
    group by h.CustomerSegment, b.ProductCategory
)
select 
    Customer_segment, product_category, Transaction_Volume
from popular_product
where rank = 1
order by Customer_segment

--3) Do credit score align with accumulated fees and transaction frequency
--using the pearson correlation equation
with score_metrics as (
    select 
        CustomerScore,
        count(*) as transaction_frequency,
        sum(coalesce(creditcardfees, 0) + coalesce(insurancefees, 0) + coalesce(latepaymentamount, 0)) as total_fees
    from fact
    group by CustomerScore
),
correlation_calc as (
    select 
        -- correlation between CustomerScore and transaction frequency
        (count(*) * sum(CAST(CustomerScore AS bigint) * transaction_frequency) - 
         sum(CAST(CustomerScore AS bigint)) * sum(transaction_frequency)) /
        nullif(sqrt(
            (count(*) * sum(CAST(CustomerScore AS bigint) * CAST(CustomerScore AS bigint)) - power(sum(CAST(CustomerScore AS bigint)), 2)) *
            (count(*) * sum(CAST(transaction_frequency AS bigint) * CAST(transaction_frequency AS bigint)) - power(sum(CAST(transaction_frequency AS bigint)), 2))
        ), 0) as corr_Txn_Frequency,
        -- correlation between CustomerScore and total fees
        (count(*) * sum(CAST(CustomerScore AS bigint) * total_fees) - 
         sum(CAST(CustomerScore AS bigint)) * sum(total_fees)) /
        nullif(sqrt(
            (count(*) * sum(CAST(CustomerScore AS bigint) * CAST(CustomerScore AS bigint)) - power(sum(CAST(CustomerScore AS bigint)), 2)) *
            (count(*) * sum(CAST(total_fees AS float) * CAST(total_fees AS float)) - power(sum(CAST(total_fees AS float)), 2))
        ), 0) as corr_Accumulated_fees
    from score_metrics
)
select 
    corr_Txn_Frequency,
    corr_Accumulated_fees
from correlation_calc;

--B) TRANSACTION BEHAVIOUR ANALYSIS 
--1) What are the dominant transaction types by transaction volumne and value
select i.TransactionType, count(J.TransactionID) as Transaction_volume from 
fact as j
inner join txn_type as i on j.transactiontypeid = i.transactiontypeid
group by i.TransactionType
order by Transaction_volume desc

select i.TransactionType, sum(Amt) as Transaction_Amount from 
fact as j
inner join txn_type as i on j.transactiontypeid = i.transactiontypeid
group by i.TransactionType
order by Transaction_Amount desc

--2) Which cities are transaction hotspots or underperformers.
select a.BranchCity, count(*) as Transaction_Volume from fact as j
inner join branch as a on j.branchcityid = a.branchcityid
group by a.BranchCity
order by Transaction_Volume desc

--3) How does usage vary between ATM, Mobile and branch banking.
select d.Channel, Count(*) as transaction_frequency, round((count(*) * 100.0) / sum(count(*)) OVER (), 2) AS percentage_usage from fact as j
inner join channel as d on j.channelid = d.channelid
group by d.Channel
order by transaction_frequency desc

--C) REVENUE AND COST INSIGHT
--1) Which transaction drive the most fee generated revenue
select i.TransactionType, sum(fees) as Accumulated_fees from fact as J
inner join txn_type as i on j.transactiontypeid = i.transactiontypeid
group by i.TransactionType
order by Accumulated_fees desc

--2) Are certain customer groups incurring disproportionate cost?
select h.CustomerSegment, count(fee_to_income) as Number_of_affected_customers
    from fact as j
    inner join segment as h on j.customersegmentid = h.customersegmentid where fee_to_income >0.15 
	group by h.CustomerSegment

select h.CustomerSegment, count(*) as Number_of_affected_customers
    from fact as j
    inner join segment as h on j.customersegmentid = h.customersegmentid where fee_to_amt > 0.15
	group by h.CustomerSegment

--3) Most frequent sources of revenue generating friction
select i.TransactionType, count(*) as Transaction_volume
    from fact as j
   inner join txn_type as i on j.transactiontypeid = i.transactiontypeid where fee_to_income >0.15 
	group by i.transactiontype

select i.TransactionType, count(*) as Transaction_volume
    from fact as j
   inner join txn_type as i on j.transactiontypeid = i.transactiontypeid where fee_to_amt >0.15 
	group by i.transactiontype

--D) TREND AND PERFORMANCE ANALYSIS
--1) Do certain months or seasons reflect transactional peaks or slowdown
select 
    year(f.transactiondate) as date_year,
    month(f.transactiondate) as date_month,
    count(*) as txn_count,
    sum(j.amt) as total_amount
from fact as j
inner join [date] as f on j.transactiondateid = f.transactiondateid
group by year(f.transactiondate), month(f.transactiondate)
order by txn_count desc, total_amount desc;

--2) are product recommendations aligned with customer behaviour?
with matched_data as (
    select
        j.TransactionID,
        case
            when c.ProductSubcategory = 'student' and g.RecommendedOffer = 'financial literacy program access' then 'Accepted'
            when c.ProductSubcategory = 'gold' and g.RecommendedOffer = 'gold card with travel benefits' then 'Accepted'
            when c.ProductSubcategory = 'standard' and g.RecommendedOffer in ('mid-tier savings booster', 'no-fee basic account') then 'Accepted'
            when c.ProductSubcategory = 'business' and g.RecommendedOffer = 'personal loan cashback offer' then 'Accepted'
            when c.ProductSubcategory = 'platinum' and g.RecommendedOffer in ('premium investment services', 'exclusive platinum package') then 'Accepted'
            else 'Rejected'
        end as is_match
    from fact as J
	inner join offer as g on j.recommendedofferid = g.recommendedofferid
    inner join subcategory as c on j.productsubcategoryid = c.productsubcategoryid
)

select is_match, count(*) as Counts, round((count(*) * 100.0) / sum(count(*)) OVER (), 2) AS percentage_usage from matched_data group by is_match

--3) what trend occurs across channels and segment over time
--Segment
select h.customersegment, 
    year(f.transactiondate) as date_year,
    month(f.transactiondate) as date_month,
    count(*) as txn_count,
    sum(j.amt) as total_amount
from fact as j
inner join [date] as f on j.transactiondateid = f.transactiondateid
inner join segment as h on j.customersegmentid = h.customersegmentid
group by year(f.transactiondate), month(f.transactiondate),h.CustomerSegment
order by year(f.transactiondate), month(f.transactiondate)

--channel
select d.Channel, 
    year(f.transactiondate) as date_year,
    month(f.transactiondate) as date_month,
    count(*) as txn_count,
    sum(j.amt) as total_amount
from fact as j
inner join [date] as f on j.transactiondateid = f.transactiondateid
inner join channel as d on j.channelid = d.channelid
group by year(f.transactiondate), month(f.transactiondate),d.Channel
order by year(f.transactiondate), month(f.transactiondate)


--for detailed information
with ranked_data as (
    select 
        h.customersegment,
        year(f.transactiondate) as date_year,
        month(f.transactiondate) as date_month,
        count(*) as txn_count,
        sum(j.amt) as total_amount,
        row_number() over (partition by h.customersegment order by count(*) desc) as rank
    from fact as j
    inner join [date] as f on j.transactiondateid = f.transactiondateid
    inner join segment as h on j.customersegmentid = h.customersegmentid
    group by h.customersegment, year(f.transactiondate), month(f.transactiondate)
)
select 
    customersegment,
    date_year,
    date_month,
    txn_count,
    total_amount,
    rank
from ranked_data
where rank = 1
order by date_year, date_month, customersegment


with ranked_data as (
    select 
        d.Channel,
        year(f.transactiondate) as date_year,
        month(f.transactiondate) as date_month,
        count(*) as txn_count,
        sum(j.amt) as total_amount,
        row_number() over (partition by d.channel order by count(*) desc) as rank
    from fact as j
    inner join [date] as f on j.transactiondateid = f.transactiondateid
    inner join channel as d on j.channelid = d.channelid
    group by d.Channel, year(f.transactiondate), month(f.transactiondate)
)
select 
    channel,
    date_year,
    date_month,
    txn_count,
    total_amount,
    rank
from ranked_data
where rank = 1
order by date_year, date_month, channel

