function [Result, Position] = FastWordDetect(Word, List)
% Accepts List as a cell array of words to check against
Result = 0; Position = 0;
Wsize = length(Word);
for x = 1:length(List)
    if length(List{x}) == Wsize
        if sum(List{x} == Word) == Wsize
            Result = 1;
            Position = x;
            return
        end
    end
end