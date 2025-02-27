clc;
clear all;
format long

% Input files
input_file_prices  = 'Daily_closing_prices.csv';

% Read daily prices
if(exist(input_file_prices,'file'))
  fprintf('\nReading daily prices datafile - %s\n', input_file_prices)
  fid = fopen(input_file_prices);
     % Read instrument tickers
     hheader  = textscan(fid, '%s', 1, 'delimiter', '\n');
     headers = textscan(char(hheader{:}), '%q', 'delimiter', ',');
     tickers = headers{1}(2:end);
     % Read time periods
     vheader = textscan(fid, '%[^,]%*[^\n]');
     dates = vheader{1}(1:end);
  fclose(fid);
  data_prices = dlmread(input_file_prices, ',', 1, 1);
else
  error('Daily prices datafile does not exist')
end

% Convert dates into array [year month day]
format_date = 'mm/dd/yyyy';
dates_array = datevec(dates, format_date);
dates_array = dates_array(:,1:3);

% Find the number of trading days in Nov-Dec 2014 and
% compute expected return and covariance matrix for period 1
day_ind_start0 = 1;
day_ind_end0 = length(find(dates_array(:,1)==2014));
cur_returns0 = data_prices(day_ind_start0+1:day_ind_end0,:) ./ data_prices(day_ind_start0:day_ind_end0-1,:) - 1;
mu = mean(cur_returns0)';
Q = cov(cur_returns0);

% Remove datapoints for year 2014
data_prices = data_prices(day_ind_end0+1:end,:);
dates_array = dates_array(day_ind_end0+1:end,:);
dates = dates(day_ind_end0+1:end,:);

% Initial positions in the portfolio
init_positions = [5000 950 2000 0 0 0 0 2000 3000 1500 0 0 0 0 0 0 1001 0 0 0]';

% Initial value of the portfolio
init_value = data_prices(1,:) * init_positions;
fprintf('\nInitial portfolio value = $ %10.2f\n\n', init_value);

% Initial portfolio weights
w_init = (data_prices(1,:) .* init_positions')' / init_value;

% Number of periods, assets, trading days
N_periods = 6*length(unique(dates_array(:,1))); % 6 periods per year
N = length(tickers);
N_days = length(dates);

% Annual risk-free rate for years 2015-2016 is 2.5%
r_rf = 0.025;

% Number of strategies
strategy_functions = {'strat_buy_and_hold' 'strat_equally_weighted' 'strat_min_variance' 'strat_max_Sharpe'};
strategy_names     = {'Buy and Hold' 'Equally Weighted Portfolio' 'Mininum Variance Portfolio' 'Maximum Sharpe Ratio Portfolio'};
N_strat = 1; % comment this in your code
% N_strat = length(strategy_functions); % uncomment this in your code
fh_array = cellfun(@str2func, strategy_functions, 'UniformOutput', false);

for (period = 1:N_periods)
    % Compute current year and month, first and last day of the period
    if(dates_array(1,1)==15)
        cur_year  = 15 + floor(period/7);
    else
        cur_year  = 2015 + floor(period/7);
    end
    cur_month = 2*rem(period-1,6) + 1;
    day_ind_start = find(dates_array(:,1)==cur_year & dates_array(:,2)==cur_month, 1, 'first');
    day_ind_end = find(dates_array(:,1)==cur_year & dates_array(:,2)==(cur_month+1), 1, 'last');
    fprintf('\nPeriod %d: start date %s, end date %s\n', period, char(dates(day_ind_start)), char(dates(day_ind_end)));

   % Prices for the current day
   cur_prices = data_prices(day_ind_start,:);

   % Execute portfolio selection strategies
   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%    for(strategy = 1:N_strat)


  if period < 2
          strategy = 2;%N_strat(2);
  else
          strategy = 1;% N_strat(1);
          
   
       % Get current portfolio positions
            if(period==1)
               curr_positions = init_positions;
               curr_cash = 0;
               portf_value{strategy} = zeros(N_days,1);
           else
               curr_positions = x{strategy,period-1};
               curr_cash = cash{strategy,period-1};
      end
      
  
      % Compute strategy
      [x{strategy,period} cash{strategy,period}] = fh_array{strategy}(curr_positions, curr_cash, mu, Q, cur_prices);

      % Verify that strategy is feasible (you have enough budget to re-balance portfolio)
      % Check that cash account is >= 0
      % Check that we can buy new portfolio subject to transaction costs

      %%%%%%%%%%% Insert your code here %%%%%%%%%%%%
      % Verify of the cash balance is negative 
      % Compute portfolio value
      portf_value{strategy}(day_ind_start:day_ind_end) = data_prices(day_ind_start:day_ind_end,:) * x{strategy,period} + cash{strategy,period};
      Transcation_Cost =cur_prices*abs(curr_positions-x{strategy,period})*0.005;
      diff = cash{strategy,period} - Transcation_Cost;
      while diff < 0
          period_return = data_prices(day_ind_end,:)./data_prices(day_ind_start,:) - 1;
          compare = period_return ./ (x{strategy,period}');
          compare = subs(compare, -inf, inf);
          index_cash = find(compare == min(compare(:)));
          x{strategy,period}([index_cash]) = x{strategy,period}([index_cash]) - 1;
          cash{strategy,period} = cash{strategy,period} + cur_prices([index_cash]);
          Transcation_Cost =cur_prices*abs(curr_positions-x{strategy,period})*0.005;
          diff = cash{strategy,period} - Transcation_Cost;
      end
      cash{strategy,period} = diff;
      
  
     
      
      % try purchase stock if cash can buy stocks 
      % current methodology: purchase stock with highest return; 
      period_return = data_prices(day_ind_end,:)./data_prices(day_ind_start,:) - 1;
      [sortedX, sortedInds] = sort(period_return(:),'descend');
      Z = 1; 
      while Z < 21
          if cash{strategy,period} > cur_prices([sortedInds(Z:Z)])*1.005
              while cash{strategy,period} > cur_prices([sortedInds(Z:Z)])*1.005
                  index_buy = sortedInds(Z:Z);
                  cash{strategy,period} = cash{strategy,period} - cur_prices([index_buy])*1.005;
                  Transcation_Cost = Transcation_Cost + cur_prices([index_buy])*0.005;
                  if cash{strategy,period} < min(cur_prices(:))*1.005
                      break
                  end
              end
          else
              Z = Z +1;
          end
      end
      
      fprintf('   Strategy "%s", value begin = $ %10.2f, value end = $ %10.2f\n', char(strategy_names{strategy}), portf_value{strategy}(day_ind_start), portf_value{strategy}(day_ind_end));

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
% % for portfolio composition drawing
%     if strategy == 3
%         w_matrix=(data_prices(day_ind_end:day_ind_end,:).*x{strategy,period}'/portf_value{strategy}(day_ind_end));
%         if period == 1
%             initial_w_matrix=(data_prices(day_ind_start:day_ind_start,:).*init_positions'/portf_value{strategy}(day_ind_start));
%             A = [initial_w_matrix; w_matrix];
%         else
%             A = [A; w_matrix];
%         end
%     end
% 
%     % for portfolio composition drawing
%     if strategy == 4
%         w_matrix4=(data_prices(day_ind_end:day_ind_end,:).*x{strategy,period}'/portf_value{strategy}(day_ind_end));
%         if period == 1
%             initial_w_matrix4=(data_prices(day_ind_start:day_ind_start,:).*init_positions'/portf_value{strategy}(day_ind_start));
%             B = [initial_w_matrix4; w_matrix4];
%         else
%             B = [B; w_matrix4];
%         end
%     end
% end
      
   % Compute expected returns and covariances for the next period
   cur_returns = data_prices(day_ind_start+1:day_ind_end,:) ./ data_prices(day_ind_start:day_ind_end-1,:) - 1;
   mu = mean(cur_returns)';
   Q = cov(cur_returns);
end

% Plot results

% figure(1);
%%%%%%%%%%% Insert your code here %%%%%%%%%%%%
% Figure#1: portfolio value for 4 different strategies 
figure(1);
set(gcf, 'color', 'white');
plot(portf_value{1}(:), 'k-', 'LineWidth', 1)
hold on;
plot(portf_value{2}(:), 'r-', 'LineWidth', 1)
hold on; 
plot(portf_value{3}(:), 'b-', 'LineWidth', 1)
hold on; 
plot(portf_value{4}(:), 'm-', 'LineWidth', 1)
xlabel('Days');
ylabel('Portfolio Value');
title('Portfolio Value for each strategy')
legend('Location','southeast')
legend('Buy and Hold', 'Equally Weighted Portfolio', 'Mininum Variance Portfolio', 'Maximum Sharpe Ratio Portfolio')  

% Figure#2: Dynamic Changes in Portfolio Allocations - Min Variance Strategy
figure(2);
x = [0 1 2 3 4 5 6 7 8 9 10 11 12];
plot(x,A)
xlabel('Periods');
ylabel('Weights');
title('Dynamic Changes in Portfolio Allocations - Strategy Min Variance')
legend('MSFT', 'F', 'CRAY', 'GOOG', 'HPQ', 'YHOO', 'HOG', 'VZ', 'AAPL', 'IBM', 'T', 'CSCO', 'BAC', 'INTC', 'AMD', 'SNE', 'NVDA', 'AMZN', 'MS', 'BK');
ylim([0 1])

% Figure#3: Dynamic Changes in Portfolio Allocations - Max Sharpe Strategy
figure(3);
x = [0 1 2 3 4 5 6 7 8 9 10 11 12];
plot(x,B)
xlabel('Periods');
ylabel('Weights');
title('Dynamic Changes in Portfolio Allocations - Strategy Max Sharpe')
legend('MSFT', 'F', 'CRAY', 'GOOG', 'HPQ', 'YHOO', 'HOG', 'VZ', 'AAPL', 'IBM', 'T', 'CSCO', 'BAC', 'INTC', 'AMD', 'SNE', 'NVDA', 'AMZN', 'MS', 'BK');
ylim([0 1])